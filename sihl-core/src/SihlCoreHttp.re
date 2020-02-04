module Header = {
  type t = Js.Dict.t(string);
};

module Status = {
  type t = int;
};

module type REQUEST = {
  type t;

  let params: t => Js.Dict.t(Js.Json.t);
  let param: (string, t) => option(Js.Json.t);
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
