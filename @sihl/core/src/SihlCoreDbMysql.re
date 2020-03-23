module Async = SihlCoreAsync;

module Bool = {
  let encoder = i => i ? Js.Json.number(1.0) : Js.Json.number(0.0);
  let decoder = j => {
    switch (Js.Json.decodeNumber(j)) {
    | Some(0.0) => Ok(false)
    | Some(1.0) => Ok(true)
    | _ => Decco.error(~path="", "Not a boolean", j)
    };
  };
  [@decco]
  type t = [@decco.codec (encoder, decoder)] bool;
};

type connection_details = {
  .
  "user": string,
  "host": string,
  "database": string,
  "password": string,
  "port": int,
  "waitForConnections": bool,
  "connectionLimit": int,
  "queueLimit": int,
};

module QueryResult = {
  [@decco]
  type t = (list(Js.Json.t), Js.Json.t);
  let decode = SihlCoreError.Decco.stringifyDecoder(t_decode);
};

module ExecutionResult = {
  [@decco]
  type meta = {
    fieldCount: int,
    affectedRows: int,
    insertId: int,
    info: string,
    serverStatus: int,
    warningStatus: int,
  };
  [@decco]
  type t = (meta, unit);
  let decode = SihlCoreError.Decco.stringifyDecoder(t_decode);
};

module Connection = {
  type t;
  [@bs.send]
  external query_: (t, string, Js.Json.t) => Js.Promise.t(Js.Json.t) =
    "query";

  let query = (~connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);
    result |> QueryResult.decode |> Async.async;
  };

  let execute = (~connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);
    result |> ExecutionResult.decode |> Async.async;
  };

  [@bs.send] external release: t => unit = "release";

  let release: t => unit =
    connection =>
      try(release(connection)) {
      | Js.Exn.Error(e) =>
        switch (Js.Exn.message(e)) {
        | Some(message) => SihlCoreLog.error(message, ())
        | None => SihlCoreLog.error("Failed to release client", ())
        }
      };
};

module Pool = {
  type t;

  [@bs.send]
  external connect: t => Js.Promise.t(Connection.t) = "getConnection";
  let connect: t => Js.Promise.t(Connection.t) = pool => connect(pool);

  [@bs.send] external end_: t => unit = "end";
  let end_ = pool =>
    try(end_(pool)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => SihlCoreLog.error(message, ())
      | None => SihlCoreLog.error("Failed to end pool", ())
      }
    };
};

[@bs.module "mysql2/promise"]
external pool: connection_details => Pool.t = "createPool";
let pool = connection_details => pool(connection_details);
