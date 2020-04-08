// Based on https://github.com/mrmurphy/serbet/tree/a86cbd097ecaf78a7ef303c2dd117021f27a1891
// Thanks to the author Murphy Randle
// We'll consider creating a PR once our API is more stable

module Async = SihlCore_Common.Async;
module Core = SihlCore_App_Http_Core;

module Endpoint = {
  open SihlCore_Common_Async;

  module Status = {
    include Express.Response.StatusCode;
  };

  type request('body, 'query, 'params) = {
    req: Express.Request.t,
    requireBody: Decco.decoder('body) => Async.t('body),
    requireQuery: Decco.decoder('query) => Async.t('query),
    requireParams: Decco.decoder('params) => Async.t('params),
    requireHeader: string => Async.t(string),
  };

  type response =
    | BadRequest(string)
    | NotFound(string)
    | Unauthorized(string)
    | Forbidden(string)
    | OkString(string)
    | OkHtml(string)
    | OkHtmlWithHeaders(string, Js.Dict.t(string))
    | OkJson(Js.Json.t)
    | OkHeaders(Js.Dict.t(string))
    | OkBuffer(Node.Buffer.t)
    | OkFile(string)
    | StatusString(Status.t, string)
    | StatusJson(Status.t, Js.Json.t)
    | TemporaryRedirect(string)
    | FoundRedirect(string)
    | InternalServerError
    | RespondRaw(Express.Response.t => Express.complete)
    | RespondRawAsync(Express.Response.t => promise(Express.complete));

  exception HttpException(response);

  let abort = res => {
    raise(HttpException(res));
  };

  let abortIfErrResponse = res => {
    switch (res) {
    | Ok(res) => res
    | Error(error) => raise(HttpException(error))
    };
  };

  let abortIfErr = (errorResponse, result) => {
    SihlCore_Common_Async.mapAsync(result, result =>
      switch (result) {
      | Ok(result) => result
      | Error(msg) =>
        SihlCore_Common.Log.error("HTTP error=" ++ msg, ());
        raise(HttpException(errorResponse));
      }
    );
  };

  type verb =
    | GET
    | POST
    | PUT
    | DELETE;

  type guard('a) = Express.Request.t => promise('a);

  module ExpressTools = {
    let queryJson = (req: Express.Request.t): Js.Json.t =>
      Obj.magic(Express.Request.query(req));

    [@bs.send] external appSet: (Express.App.t, string, 'a) => unit = "set";

    [@bs.module]
    external middlewareAsComplete:
      (Express.Middleware.t, Express.Request.t, Express.Response.t) =>
      Async.t(Express.complete) =
      "./http/middleware-as-complete.js";
  };

  let requireHeader: string => guard(string) =
    (headerName, req) => {
      let o = req |> Express.Request.get(headerName);
      switch (o) {
      | Some(h) => async(h)
      | None => abort @@ BadRequest("Missing required header: " ++ headerName)
      };
    };

  let requireBody: Decco.decoder('body) => guard('body) =
    (decoder, req) => {
      // We resolve a promise first so that if the decoding
      // fails, it will reject the promise instead of just
      // throwing and requiring a try/catch.
      let%Async _ = async();
      switch (req |> Express.Request.bodyJSON) {
      | Some(rawBodyJson) =>
        switch (decoder(rawBodyJson)) {
        | Error(e) =>
          abort(
            BadRequest(
              "Could not decode expected body: location="
              ++ e.path
              ++ ", message="
              ++ e.message,
            ),
          )
        | Ok(v) => v->async
        }
      | None => abort @@ BadRequest("Body required")
      };
    };

  let requireParams: Decco.decoder('params) => guard('params) =
    (decoder, req) => {
      let paramsAsJson: Js.Json.t = Obj.magic(req |> Express.Request.params);
      // We resolve a promise first so that if the decoding
      // fails, it will reject the promise instead of just
      // throwing and requiring a try/catch.
      let%Async _ = async();
      switch (decoder(paramsAsJson)) {
      | Error(e) =>
        abort @@
        BadRequest(
          "Could not decode expected params from the URL path: location="
          ++ e.path
          ++ ", message="
          ++ e.message,
        )
      | Ok(v) => async @@ v
      };
    };

  let requireQuery: Decco.decoder('query) => guard('query) =
    (decoder, req) => {
      // We resolve a promise first so that if the decoding
      // fails, it will reject the promise instead of just
      // throwing and requiring a try/catch.
      let%Async _ = async();
      switch (decoder(ExpressTools.queryJson(req))) {
      | Error(e) =>
        abort @@
        BadRequest(
          "Could not decode expected params from query string: location="
          ++ e.path
          ++ ", message="
          ++ e.message,
        )
      | Ok(v) => async @@ v
      };
    };

  [@bs.module]
  external jsonParsingMiddleware: Express.Middleware.t =
    "./http/json-parsing-middleware.js";

  [@bs.module]
  external cookieParsingMiddleware: Express.Middleware.t =
    "./http/cookie-parsing-middleware.js";

  [@bs.module]
  external formDataParsingMiddleware: Express.Middleware.t =
    "./http/form-data-parsing-middleware.js";

  type endpointConfig('body_in, 'params, 'query) = {
    path: string,
    verb,
    handler: request('body_in, 'params, 'query) => Async.t(response),
  };

  let verb = endpoint => endpoint.verb;

  type dbEndpointConfig('database, 'connection, 'body_in, 'params, 'query) = {
    database: 'database,
    path: string,
    verb,
    handler:
      ('connection, request('body_in, 'params, 'query)) => Async.t(response),
  };

  type jsonEndpointConfig('body_in, 'params, 'query, 'body_out) = {
    path: string,
    verb,
    body_in_decode: Decco.decoder('body_in),
    body_out_encode: Decco.encoder('body_out),
    handler:
      ('body_in, request('body_in, 'params, 'query)) => Async.t('body_out),
  };

  let sendRequestedContent = (msg, req, res) => {
    Express.Response.(
      switch (Express.Request.get("content-type", req)) {
      | Some("text/plain; charset=utf-8") => sendString(msg, res)
      | Some("text/html; charset=utf-8") => sendString(msg, res)
      // Default is to send JSON
      | _ => sendJson(Js.Json.parseExn({j|{"msg": "$(msg)"}|j}), res)
      }
    );
  };
  let _resToExpressRes = (req, res, handlerRes) => {
    switch (handlerRes) {
    | BadRequest(msg) =>
      async @@
      Express.Response.(
        res |> status(Status.BadRequest) |> sendRequestedContent(msg, req)
      )
    | NotFound(msg) =>
      async @@
      Express.Response.(
        res |> status(Status.NotFound) |> sendRequestedContent(msg, req)
      )
    | Unauthorized(msg) =>
      async @@
      Express.Response.(
        res |> status(Status.Unauthorized) |> sendRequestedContent(msg, req)
      )
    | Forbidden(msg) =>
      async @@
      Express.Response.(
        res |> status(Status.Forbidden) |> sendRequestedContent(msg, req)
      )
    | OkString(msg) =>
      async @@
      Express.Response.(
        res
        |> status(Status.Ok)
        |> setHeader("content-type", "text/plain; charset=utf-8")
        |> sendString(msg)
      )
    | OkHtml(msg) =>
      async @@
      Express.Response.(
        res
        |> status(Status.Ok)
        |> setHeader("content-type", "text/html; charset=utf-8")
        |> sendString(msg)
      )
    | OkHtmlWithHeaders(msg, headers) =>
      Js.Dict.set(headers, "content-type", "text/html; charset=utf-8");
      open Express.Response;
      let res =
        headers
        ->Js.Dict.entries
        ->Belt.List.fromArray
        ->Belt.List.reduce(res, (res, (key, value)) =>
            setHeader(key, value, res)
          );
      async @@ (res |> status(Status.Ok) |> sendString(msg));
    | OkJson(js) =>
      async @@ Express.Response.(res |> status(Status.Ok) |> sendJson(js))
    | OkHeaders(headers) =>
      open Express.Response;
      let res =
        headers
        ->Js.Dict.entries
        ->Belt.List.fromArray
        ->Belt.List.reduce(res, (res, (key, value)) =>
            setHeader(key, value, res)
          );
      let result = res |> sendStatus(Express.Response.StatusCode.Ok);
      async(result);
    | OkBuffer(buff) =>
      async @@
      Express.Response.(res |> status(Status.Ok) |> sendBuffer(buff))
    | OkFile(path) =>
      async @@
      Express.Response.(
        res
        |> status(Status.Ok)
        |> sendFile(path, {"root": Node.Process.cwd()})
      )
    | StatusString(stat, msg) =>
      async @@
      Express.Response.(
        res
        |> status(stat)
        |> setHeader("content-type", "text/plain; charset=utf-8")
        |> sendString(msg)
      )
    | StatusJson(stat, js) =>
      async @@ Express.Response.(res |> status(stat) |> sendJson(js))
    | InternalServerError =>
      async @@
      Express.Response.(
        res |> sendStatus(Express.Response.StatusCode.InternalServerError)
      )
    | TemporaryRedirect(location) =>
      async @@
      Express.Response.(
        res
        |> setHeader("Location", location)
        |> sendStatus(StatusCode.TemporaryRedirect)
      )
    | FoundRedirect(location) =>
      async @@
      Express.Response.(
        res
        |> setHeader("Location", location)
        |> sendStatus(StatusCode.Found)
      )
    | RespondRaw(fn) => async @@ fn(res)
    | RespondRawAsync(fn) => fn(res)
    };
  };

  let defaultMiddleware = [|
    // By default we parse JSON bodies and cookies
    jsonParsingMiddleware,
    cookieParsingMiddleware,
    formDataParsingMiddleware,
  |];

  let endpoint =
      (~middleware=?, cfg: endpointConfig('body, 'params, 'query))
      : Core.endpoint => {
    let wrappedHandler = (_next, req, res) => {
      let handleOCamlError =
        [@bs.open]
        (
          fun
          | HttpException(handlerResponse) => handlerResponse
        );
      let handleError = error => {
        switch (handleOCamlError(error)) {
        | Some(res) => res->async
        | None =>
          switch (Obj.magic(error)##stack) {
          | Some(stack) => Js.log2("Unhandled internal server error", stack)
          | None => Js.log2("Unhandled internal server error", error)
          };
          InternalServerError->async;
        };
      };

      let request = {
        req,
        requireBody: a => requireBody(a, req),
        requireQuery: a => requireQuery(a, req),
        requireParams: a => requireParams(a, req),
        requireHeader: a => requireHeader(a, req),
      };

      switch (cfg.handler(request)) {
      | exception err =>
        let%Async r = handleError(err);
        _resToExpressRes(req, res, r);
      | p =>
        let%Async r = p->catchAsync(handleError);
        _resToExpressRes(req, res, r);
      };
    };
    let expressHandler = Express.PromiseMiddleware.from(wrappedHandler);

    let verbFunction =
      switch (cfg.verb) {
      | GET => Express.App.getWithMany
      | POST => Express.App.postWithMany
      | PUT => Express.App.putWithMany
      | DELETE => Express.App.deleteWithMany
      };

    let verbFunctionForRouter =
      switch (cfg.verb) {
      | GET => Express.Router.getWithMany
      | POST => Express.Router.postWithMany
      | PUT => Express.Router.putWithMany
      | DELETE => Express.Router.deleteWithMany
      };

    {
      use: app => {
        app->verbFunction(
          ~path=cfg.path,
          Belt.Array.concat(
            middleware->Belt.Option.getWithDefault(defaultMiddleware),
            [|expressHandler|],
          ),
        );
      },

      useOnRouter: router => {
        router->verbFunctionForRouter(
          ~path=cfg.path,
          Belt.Array.concat(
            middleware->Belt.Option.getWithDefault(defaultMiddleware),
            [|expressHandler|],
          ),
        );
      },
    };
  };

  let jsonEndpoint =
      (
        ~middleware=?,
        cfg: jsonEndpointConfig('body_in, 'query, 'params, 'body_out),
      )
      : Core.endpoint => {
    endpoint(
      ~middleware?,
      {
        path: cfg.path,
        verb: cfg.verb,
        handler: req => {
          let%Async body = req.requireBody(cfg.body_in_decode);
          let%Async response = cfg.handler(body, req);
          async(OkJson(cfg.body_out_encode(response)));
        },
      },
    );
  };

  let dbEndpoint =
      (
        ~middleware=?,
        cfg:
          dbEndpointConfig('database, 'connection, 'body_in, 'params, 'query),
        module I: SihlCore_Common_Db.PERSISTENCE,
      )
      : Core.endpoint => {
    endpoint(
      ~middleware?,
      {
        path: cfg.path,
        verb: cfg.verb,
        handler: req => {
          I.Database.withConnection(cfg.database, conn =>
            cfg.handler(conn, req)
          );
        },
      },
    );
  };
};

let requireAuthorizationToken =
    (request: Endpoint.request('body, 'query, 'params)) => {
  let%Async header = Endpoint.requireHeader("authorization", request.req);
  switch (Core.parseAuthToken(header)) {
  | Some(token) => Async.async(token)
  | None => Endpoint.abort(BadRequest("No authorization token found"))
  };
};

let parseCookie = (cookies, key) => {
  cookies
  ->Belt.Option.flatMap(cookies => Js.Dict.get(cookies, key))
  ->Belt.Option.flatMap(Js.Json.decodeString);
};

let sessionCookie = (request: Endpoint.request('body, 'query, 'params)) => {
  let cookieToken =
    request.req->Express.Request.cookies->parseCookie("session");
  Async.async(cookieToken);
};

let requireSessionCookie =
    (request: Endpoint.request('body, 'query, 'params), location) => {
  let%Async token = sessionCookie(request);
  switch (token) {
  | Some(token) => Async.async(token)
  | _ => Endpoint.abort(FoundRedirect(location))
  };
};

module Express = Express;

let endpoint = Endpoint.endpoint;
let dbEndpoint = Endpoint.dbEndpoint;
let jsonEndpoint = Endpoint.jsonEndpoint;

type application = {
  httpServer: Express.HttpServer.t,
  expressApp: Express.App.t,
  router: Express.Router.t,
};

let application = (~port=?, endpoints: list(Core.endpoint)) => {
  let app = Express.App.make();
  let router = Express.Router.make();
  app->Express.App.useRouter(router);

  endpoints->Belt.List.forEach(ep => {ep.useOnRouter(router)});

  let defaultPort =
    Node.Process.process##env
    ->Js.Dict.get("PORT")
    ->Belt.Option.map(a => Js.Float.fromString(a)->int_of_float)
    ->Belt.Option.getWithDefault(3000);

  let effectivePort = port->Belt.Option.getWithDefault(defaultPort);

  let httpServer =
    app->Express.App.listen(
      ~port=effectivePort,
      ~onListen=
        _ => {
          SihlCore_Common.Log.info(
            "Server listening on port " ++ string_of_int(effectivePort),
            (),
          )
        },
      (),
    );

  Express.HttpServer.on(
    httpServer,
    `close(_ => SihlCore_Common.Log.info("Closing http server", ())),
  );

  {httpServer, expressApp: app, router};
};

let closeServer: Express.HttpServer.t => unit = [%bs.raw
  {| server => server.close() |}
];

let shutdown = app => {
  app.httpServer |> closeServer;
  // this is a hack, we are waiting for the server to shutdown
  SihlCore_Common_Async.wait(500);
};
