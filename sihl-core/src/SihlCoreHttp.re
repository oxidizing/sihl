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
};

module Message = {
  [@decco]
  type t = {message: string};
  let encode = t_encode;
  let make = message => {message: message};
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
  module MiddleWare = {
    type t = Handler.t => Handler.t;
  };
};
