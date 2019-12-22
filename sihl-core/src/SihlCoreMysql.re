let errorTransformer = err => `ServerError(Js.String.make(err));

let (>>=) = Future.(>>=);

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
  type result = (list(Js.Json.t), Js.Json.t);
  let make = (result, meta) => (result, meta);
};

module MutationResult = {
  type result = Js.Json.t;
  let make = result => result;
};

module Connection = {
  type t;
  [@bs.send]
  external query_: (t, string, Js.Json.t) => Js.Promise.t(Js.Json.t) =
    "query";
  [@bs.send] external release: t => unit = "release";

  let query = (~connection, ~stmt, ~values, ()) => {
    let values =
      Rationale.Option.default(Json.Encode.boolArray([||]), values);
    FutureJs.fromPromise(query_(connection, stmt, values), errorTransformer);
  };

  let mutate = (~connection, ~stmt, ~values=?, ()) => {
    let values =
      Rationale.Option.default(Json.Encode.boolArray([||]), values);
    FutureJs.fromPromise(query_(connection, stmt, values), errorTransformer);
  };

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
  let connect:
    t => Future.t(Belt.Result.t(Connection.t, [> SihlCoreError.t])) =
    pool => FutureJs.fromPromise(connect(pool), errorTransformer);
};

[@bs.module "mysql2/promise"]
external pool: connection_details => Pool.t = "createPool";
let pool = connection_details => pool(connection_details);
