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

  let raw = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    query_(connection, stmt, parameters);
  };

  let getMany = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);
    let rows =
      result->MysqlResult.Query.decode->Belt.Result.map(((rows, _)) => rows);
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

  let getOne = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result =
      query_(connection, stmt, parameters)
      ->Async.mapAsync(result =>
          result
          ->MysqlResult.Query.decode
          ->Belt.Result.map(((rows, _)) => rows)
        );
    Async.async(
      switch (result) {
      | Ok([row]) => Ok(row)
      | Ok([]) =>
        Error(
          "No rows found in database "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      | Ok(_) =>
        Error(
          "Two or more rows found when we were expecting only one "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      | Error(msg) =>
        Sihl.Core.Db.abort(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      },
    );
  };

  let execute = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    query_(connection, stmt, parameters)
    ->Async.mapAsync(result =>
        result
        ->MysqlResult.Execution.decode
        ->Belt.Result.map(((MysqlResult.Execution.{affectedRows}, _)) =>
            Sihl.Core.Db.Result.Execution.make(affectedRows)
          )
      );
  };

  let withTransaction: (t, t => Js.Promise.t('a)) => Js.Promise.t('a) =
    (connection, f) => {
      let%Async _ =
        execute(connection, ~stmt="START TRANSACTION;", ~parameters=None);
      let%Async result = f(connection);
      let%Async _ =
        execute(connection, ~stmt="COMMIT;", ~parameters=None)
        ->Async.catchAsync(error => {
            Sihl.Core.Log.error(
              "error happened while commiting the transaction, rolling back",
              (),
            );
            Js.log(error);
            execute(connection, ~stmt="ROLLBACK;", ~parameters=None);
          });
      Async.async(result);
    };
};

module Database = {
  type handle;
  type t = {
    name: string,
    handle,
  };

  [@bs.module "mysql2/promise"]
  external setup: Sihl.Core.Db.Config.t => handle = "createPool";
  [@bs.send] external end_: handle => unit = "end";
  [@bs.send]
  external connect: handle => Async.t(Connection.t) = "getConnection";

  let setup = (databaseUrl: Sihl.Core.Config.Db.Url.t) => {
    let config: Sihl.Core.Config.Db.t =
      Sihl.Core.Config.Db.makeFromUrl(databaseUrl)
      |> Sihl.Core.Error.failIfError;
    let handle =
      setup({
        "user": config.dbUser,
        "host": config.dbHost,
        "database": config.dbName,
        "password": config.dbPassword,
        "port": config.dbPort |> int_of_string,
        "waitForConnections": true,
        "connectionLimit": config.connectionLimit |> int_of_string,
        "queueLimit": config.queueLimit |> int_of_string,
      });
    {name: config.dbName, handle};
  };

  let end_ = db =>
    try(end_(db.handle)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => Sihl.Core.Log.error(message, ())
      | None => Sihl.Core.Log.error("Failed to end pool", ())
      }
    };

  let connect = db => connect(db.handle);

  let withConnection = (db, f) => {
    let%Async conn = connect(db);
    let%Async result = f(conn);
    Connection.release(conn);
    Async.async(result);
  };

  module Clean = {
    [@decco]
    type t = {command: string};

    let stmt = ({name}) => {j|
  SELECT
  CONCAT('TRUNCATE TABLE ',TABLE_NAME,';') AS command
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = '$(name)';
|j};

    let query = db => {
      let stmt = stmt(db);
      withConnection(
        db,
        conn => {
          let%Async _ =
            Connection.execute(
              conn,
              ~stmt="SET FOREIGN_KEY_CHECKS = 0;",
              ~parameters=None,
            );
          let%Async commands =
            Connection.getMany(conn, ~stmt, ~parameters=None);
          let commands =
            switch (commands) {
            | Ok((rows, _)) =>
              rows
              ->Belt.List.map(
                  Sihl.Core.Error.Decco.stringifyDecoder(t_decode),
                )
              ->Belt.List.map(result =>
                  switch (result) {
                  | Ok(result) => result
                  | Error(msg) =>
                    Sihl.Core.Db.abort(
                      "Error happened in DB when getMany() msg="
                      ++ msg
                      ++ Sihl.Core.Db.debug(stmt, None),
                    )
                  }
                )
            | Error(msg) =>
              Sihl.Core.Db.abort(
                "Error happened in DB when getMany() msg="
                ++ msg
                ++ Sihl.Core.Db.debug(stmt, None),
              )
            };
          let%Async _ =
            commands
            ->Belt.List.map(({command}, ()) => {
                command !== "TRUNCATE TABLE core_migration_status;"
                  ? Connection.execute(conn, ~stmt=command, ~parameters=None)
                    ->Async.mapAsync(_ => ())
                  : Async.async()
              })
            ->Sihl.Core.Async.allInOrder;

          let%Async _ =
            Connection.execute(
              conn,
              ~stmt="SET FOREIGN_KEY_CHECKS = 1;",
              ~parameters=None,
            );
          Async.async();
        },
      );
    };
  };
  let clean = Clean.query;
};
