module Async = Sihl.Core.Async;

let setup = Bindings.setup;
let end_ = pool =>
  try(Bindings.end_(pool)) {
  | Js.Exn.Error(e) =>
    switch (Js.Exn.message(e)) {
    | Some(message) => Sihl.Core.Log.error(message, ())
    | None => Sihl.Core.Log.error("Failed to end pool", ())
    }
  };
let connect = Bindings.connect;
let release = connection =>
  try(Bindings.release(connection)) {
  | Js.Exn.Error(e) =>
    switch (Js.Exn.message(e)) {
    | Some(message) => Sihl.Core.Log.error(message, ())
    | None => Sihl.Core.Log.error("Failed to release client", ())
    }
  };
let querySimple = (connection, ~stmt, ~parameters) => {
  let parameters =
    Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
  Bindings.query_(connection, stmt, parameters)
  ->Async.mapAsync(result =>
      result->MysqlResult.Query.decode->Belt.Result.map(((rows, _)) => rows)
    );
};
let query:
  (
    SihlMysql.Sihl.Core.Db.Connection.t,
    ~stmt: string,
    ~parameters: option(Js.Json.t)
  ) =>
  Js.Promise.t(Belt.Result.t(SihlMysql.Sihl.Core.Db.Result.Query.t, string)) =
  (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = Bindings.query_(connection, stmt, parameters);
    let rows =
      result->MysqlResult.Query.decode->Belt.Result.map(((rows, _)) => rows);
    let%Async meta =
      Bindings.query_(
        connection,
        MysqlResult.Query.MetaData.foundRowsQuery,
        Js.Json.stringArray([||]),
      );
    let meta = meta->MysqlResult.Query.decode;
    let totalCount: int =
      switch (meta) {
      | Ok(([row], _)) =>
        switch (
          row
          |> Sihl.Core.Error.Decco.stringifyDecoder(
               MysqlResult.Query.MetaData.t_decode,
             )
        ) {
        | Ok(MysqlResult.Query.MetaData.{totalCount}) => totalCount
        | Error(_) =>
          Sihl.Core.Db.abort(
            "Error happened in DB when decoding meta "
            ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
          )
        }
      | _ =>
        Sihl.Core.Db.abort(
          "Error happened in DB when fetching FOUND_ROWS() "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      };
    rows
    ->Belt.Result.map(rows =>
        Sihl.Core.Db.Result.Query.make(rows, ~rowCount=totalCount)
      )
    ->Async.async;
  };
let execute = (connection, ~stmt, ~parameters) => {
  let parameters =
    Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
  Bindings.query_(connection, stmt, parameters)
  ->Async.mapAsync(result =>
      result
      ->MysqlResult.Execution.decode
      ->Belt.Result.map(((MysqlResult.Execution.{affectedRows}, _)) =>
          SihlCore.SihlCoreDbCore.Result.Execution.make(affectedRows)
        )
    );
};
