module Mysql = {
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
    [@decco]
    type t = (list(Js.Json.t), Js.Json.t);
    let make = (result, meta) => (result, meta);
    let decode = t_decode;
  };

  module MutationResult = {
    [@decco]
    type t = Js.Json.t;
    let make = result => result;
    let decode = t_decode;
  };

  module Connection = {
    type t;
    [@bs.send]
    external query_: (t, string, Js.Json.t) => Js.Promise.t(Js.Json.t) =
      "query";
    [@bs.send] external release: t => unit = "release";

    let query = (~connection, ~stmt, ~values, ()) => {
      let values =
        Tablecloth.Option.withDefault(
          ~default=Json.Encode.boolArray([||]),
          values,
        );
      query_(connection, stmt, values)
      ->FutureJs.fromPromise(errorTransformer)
      ->Future.flatMapOk(value =>
          value
          |> QueryResult.decode
          |> SihlCoreError.decodeToServerError
          |> Future.value
        );
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
};

module Connection = Mysql.Connection;
module Pool = Mysql.Pool;

/* type field(_) = */
/*   | Bool: field(bool) */
/*   | Int: field(int) */
/*   | Float: field(float) */
/*   | String: field(string); */

/* type t(_) = */
/*   | Unit: t(unit) */
/*   | Field(field('a)): t('a) */
/*   | Option(t('a)): t(option('a)) */
/*   | Tup2(t('a0), t('a1)): t(('a0, 'a1)) */
/*   | Tup3(t('a0), t('a1), t('a2)): t(('a0, 'a1, 'a2)) */
/*   | Tup4(t('a0), t('a1), t('a2), t('a3)): t(('a0, 'a1, 'a2, 'a3)); */

/* module Std = { */
/*   let unit = Unit; */
/*   let option = t => Option(t); */
/*   let tup2 = (t0, t1) => Tup2(t0, t1); */
/*   let tup3 = (t0, t1, t2) => Tup3(t0, t1, t2); */
/*   let tup4 = (t0, t1, t2, t3) => Tup4(t0, t1, t2, t3); */
/*   let bool = Field(Bool); */
/*   let int = Field(Int); */
/*   let float = Field(Float); */
/*   let string = Field(String); */
/* }; */

/* let test = Std.tup2(Std.bool, Std.int); */
