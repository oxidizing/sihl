module Async = Sihl.Core.Async;

module Connection = {
  type t;
  [@bs.send] external release: t => unit = "release";
  [@bs.send]
  external query_: (t, string, Js.Json.t) => Async.t(Js.Json.t) = "query";

  let release = connection =>
    try(release(connection)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => Sihl.Core.Log.error(message, ())
      | None => Sihl.Core.Log.error("Failed to release client", ())
      }
    };
  let querySimple = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    query_(connection, stmt, parameters)
    ->Async.mapAsync(result =>
        result
        ->MysqlResult.Query.decode
        ->Belt.Result.map(((rows, _)) => rows)
      );
  };
  let query:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(
      Belt.Result.t(SihlMysql.Sihl.Core.Db.Result.Query.t, string),
    ) =
    (connection, ~stmt, ~parameters) => {
      let parameters =
        Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
      let%Async result = query_(connection, stmt, parameters);
      let rows =
        result
        ->MysqlResult.Query.decode
        ->Belt.Result.map(((rows, _)) => rows);
      let%Async meta =
        query_(
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
    query_(connection, stmt, parameters)
    ->Async.mapAsync(result =>
        result
        ->MysqlResult.Execution.decode
        ->Belt.Result.map(((MysqlResult.Execution.{affectedRows}, _)) =>
            SihlCore.SihlCoreDbCore.Result.Execution.make(affectedRows)
          )
      );
  };
};

module Database = {
  type t;
  [@bs.module "mysql2/promise"]
  external setup: Sihl.Core.Db.Config.t => t = "createPool";
  [@bs.send] external end_: t => unit = "end";
  [@bs.send] external connect: t => Async.t(Connection.t) = "getConnection";

  let end_ = pool =>
    try(end_(pool)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => Sihl.Core.Log.error(message, ())
      | None => Sihl.Core.Log.error("Failed to end pool", ())
      }
    };
};

module Migration = {
  module MysqlMigration = MysqlMigration.Make(Connection);
  module Status = MysqlMigration.Status;
  let setupMigrationStorage = MysqlMigration.CreateTableIfDoesNotExist.query;
  let hasMigrationStatus = MysqlMigration.Has.query;
  let getMigrationStatus = MysqlMigration.Get.query;
  let upsertMigrationStatus = MysqlMigration.Upsert.query;
};
