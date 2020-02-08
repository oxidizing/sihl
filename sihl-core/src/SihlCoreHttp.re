module Header = {
  type t = Js.Dict.t(string);
};

module Status = {
  type t = int;
};

module type REQUEST = {
  type t;

  let params: t => Js.Dict.t(Js.Json.t);
  let param: (string, t) => Belt.Result.t(string, SihlCoreError.t);
  let header: (string, t) => option(string);
  let path: t => list(string);
  let originalUrl: t => string;
  let jsonBody: t => option(Js.Json.t);
  let authToken: t => option(string);
};

module type RESPONSE = {
  type t;

  let make:
    (
      ~header: Header.t=?,
      ~status: Status.t=?,
      ~bodyJson: Js.Json.t=?,
      ~bodyBuffer: Node.Buffer.t=?,
      ~bodyFile: string=?,
      unit
    ) =>
    t;

  let status: t => int;
  let bodyJson: t => option(Js.Json.t);
  let bodyBuffer: t => option(Node.Buffer.t);
  let bodyFile: t => option(string);
  let errorToResponse: SihlCoreError.t => t;
};

module MakeHttp = (Request: REQUEST, Response: RESPONSE) => {
  module Handler = {
    type t = Request.t => Future.t(Response.t);
  };
  module Route = {
    type verb =
      | GET
      | POST;
    type t = (verb, string, Handler.t);

    let post = (path, handler: Handler.t) => (POST, path, handler);
    let get = (path, handler: Handler.t) => (GET, path, handler);
    let handler = ((_, _, handler)) => handler;
  };
  module Middleware = {
    type t = Handler.t => Handler.t;
  };
  module type ADAPTER = {
    let startServer:
      (~port: int, list(Route.t)) => Belt.Result.t(unit, string);
  };
};

module Message = {
  [@decco]
  type t = {message: string};
  let encode = t_encode;
  let make = message => {message: message};
};

module Request: REQUEST = {
  type t = Express.Request.t;

  let params = r => r |> Express.Request.params;
  let param = (key, r) => {
    Js.Dict.get(params(r), key)
    |> SihlCoreError.optionAsResult(
         `ClientError("Parameter " ++ key ++ " not found"),
       )
    |> Tablecloth.Result.andThen(~f=p =>
         SihlCoreError.catchAsResult(
           _ => Json.Decode.string(p),
           `ClientError("Invalid request param provided " ++ key),
         )
       );
  };

  let header = (key, r) => r |> Express.Request.get(key);
  let path = r =>
    r |> Express.Request.path |> Tablecloth.String.split(~on="/");
  let originalUrl = r => r |> Express.Request.originalUrl;
  let jsonBody = r => r |> Express.Request.bodyJSON;

  let authToken = request => {
    Tablecloth.(
      request
      |> header("authorization")
      |> Option.map(~f=String.split(~on=" "))
      |> Option.andThen(~f=List.get_at(~index=1))
    );
  };
};

module Response: RESPONSE = {
  type t = {
    header: Js.Dict.t(string),
    bodyJson: option(Js.Json.t),
    bodyBuffer: option(Node.Buffer.t),
    bodyFile: option(string),
    status: int,
  };

  let status = r => r.status;
  let bodyJson = r => r.bodyJson;
  let bodyBuffer = r => r.bodyBuffer;
  let bodyFile = r => r.bodyFile;

  let make =
      (~header=?, ~status=?, ~bodyJson=?, ~bodyBuffer=?, ~bodyFile=?, ()) => {
    Tablecloth.{
      header: header |> Option.withDefault(~default=Js.Dict.empty()),
      bodyJson,
      bodyBuffer,
      bodyFile,
      status: status |> Option.withDefault(~default=200),
    };
  };

  let errorToResponse = error => {
    module Message = Message;
    SihlCoreLog.error(SihlCoreError.message(error), ());
    switch (error) {
    | `ForbiddenError(message) =>
      make(
        ~status=403,
        ~bodyJson=message |> Message.make |> Message.encode,
        (),
      )
    | `NotFoundError(message) =>
      make(
        ~status=404,
        ~bodyJson=message |> Message.make |> Message.encode,
        (),
      )
    | `AuthenticationError(message) =>
      make(
        ~status=401,
        ~bodyJson=message |> Message.make |> Message.encode,
        (),
      )
    | `ServerError(_) =>
      make(
        ~status=403,
        ~bodyJson=
          "An error occurred, our administrators have been notified."
          |> Message.make
          |> Message.encode,
        (),
      )
    | `ClientError(message) =>
      make(
        ~status=400,
        ~bodyJson=message |> Message.make |> Message.encode,
        (),
      )
    | `AuthorizationError(message) =>
      make(
        ~status=403,
        ~bodyJson=message |> Message.make |> Message.encode,
        (),
      )
    };
  };
};

include MakeHttp(Request, Response);

module Adapter: ADAPTER = {
  type expressConfig = {
    limitMb: float,
    compression: bool,
    hidePoweredBy: bool,
    urlEncoded: bool,
  };

  let makeExpressResponse =
      (internal: Response.t, external_: Express.Response.t) => {
    open Tablecloth;
    let prepared =
      external_
      |> Express.Response.status(
           internal
           |> Response.status
           |> Express.Response.StatusCode.fromInt
           |> Option.withDefault(
                ~default=Express.Response.StatusCode.BadGateway,
              ),
         );
    switch (
      Response.bodyJson(internal),
      Response.bodyBuffer(internal),
      Response.bodyFile(internal),
    ) {
    | (Some(json), _, _) => Express.Response.sendJson(json, prepared)
    | (_, Some(buffer), _) => Express.Response.sendBuffer(buffer, prepared)
    | (_, _, Some(filepath)) =>
      Express.Response.sendFile(filepath, (), prepared)
    | _ =>
      Express.Response.sendJson(
        Message.encode(Message.{message: "No body provided"}),
        prepared,
      )
    };
  };

  external makeRequest: Express.Request.t => Request.t = "%identity";

  let toPromise =
      (
        req: Request.t,
        externalResponse: Express.Response.t,
        handler: Handler.t,
      ) => {
    req
    ->handler
    ->Future.map(internal => makeExpressResponse(internal, externalResponse))
    ->FutureJs.toPromise;
  };

  let mountStaticRoute = (app, routePath, localPath) => {
    Express.App.useOnPath(
      app,
      ~path=routePath,
      {
        let options = Express.Static.defaultOptions();
        Express.Static.make(localPath, options) |> Express.Static.asMiddleware;
      },
    );
    app;
  };

  let appConfig =
      (~limitMb=?, ~compression=?, ~hidePoweredBy=?, ~urlEncoded=?, ()) => {
    Tablecloth.{
      limitMb: limitMb |> Option.withDefault(~default=10.0),
      compression: compression |> Option.withDefault(~default=true),
      hidePoweredBy: hidePoweredBy |> Option.withDefault(~default=true),
      urlEncoded: urlEncoded |> Option.withDefault(~default=true),
    };
  };

  [@bs.module]
  external compressionMiddleware: unit => Express.Middleware.t = "compression";

  let makeApp = ({limitMb, compression, hidePoweredBy, urlEncoded}) => {
    let app = Express.express();
    Express.App.use(
      app,
      Express.Middleware.json(~limit=Express.ByteLimit.mb(limitMb), ()),
    );
    if (compression) {
      Express.App.use(app, compressionMiddleware());
    };
    if (hidePoweredBy) {
      Express.App.disable(app, ~name="x-powered-by");
    };
    if (urlEncoded) {
      Express.App.use(
        app,
        Express.Middleware.urlencoded(~extended=true, ()),
      );
    };
    app;
  };

  let mountRoutes = (routes: list(Route.t), app) => {
    let _ =
      Tablecloth.List.map(
        ~f=
          r =>
            switch ((r: Route.t)) {
            | (Route.GET, path, handler) =>
              Express.App.get(
                app,
                ~path,
                Express.PromiseMiddleware.from((_, req, res) =>
                  toPromise(makeRequest(req), res, handler)
                ),
              )
            | (Route.POST, path, handler) =>
              Express.App.post(
                app,
                ~path,
                Express.PromiseMiddleware.from((_, req, res) => {
                  toPromise(makeRequest(req), res, handler)
                }),
              )
            },
        routes,
      );
    app;
  };

  let startApp = (~port, app) => {
    let onListen = e =>
      switch (e) {
      | exception (Js.Exn.Error(e)) =>
        switch (Js.Exn.message(e)) {
        | Some(message) =>
          SihlCoreLog.error("Error in express: " ++ message, ())
        | None => SihlCoreLog.error("Error in express", ())
        };
        Node.Process.exit(1);
      | _ => SihlCoreLog.info("Listening at port 3000", ())
      };

    Express.App.listen(app, ~port, ~onListen, ());
  };

  let startServer = (~port, routes) => {
    let _ =
      appConfig(
        ~limitMb=10.0,
        ~compression=true,
        ~hidePoweredBy=true,
        ~urlEncoded=true,
        (),
      )
      |> makeApp
      |> mountRoutes(routes)
      |> startApp(~port);
    Belt.Result.Ok();
  };
};

let respond:
  Future.t(Belt.Result.t(Js.Json.t, SihlCoreError.t)) =>
  Future.t(Response.t) =
  json =>
    json
    ->Future.map(json =>
        switch (json) {
        | Belt.Result.Ok(json) => json
        | Belt.Result.Error(error) =>
          error |> SihlCoreError.message |> Message.make |> Message.encode
        }
      )
    ->Future.map(bodyJson => Response.make(~bodyJson, ()));
