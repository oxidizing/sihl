module Async = Sihl.Core.Async;

module Connection = {
  type t;
  [@bs.send] external release: t => Async.t(unit) = "end";
  [@bs.send]
  external query_: (t, string, Js.Json.t) => Async.t(Js.Json.t) = "query";

  let raw = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    query_(connection, stmt, parameters);
  };

  let getMany = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);
    switch (Postgres_Result.decode(result)) {
    | Ok({rows, rowCount}) =>
      Async.async @@ Ok(Sihl.Core.Db.Result.Query.make(rows, ~rowCount))
    | Error(msg) =>
      Sihl.Core.Db.abort(
        "Error happened in DB when decoding result of getMany() msg="
        ++ msg
        ++ " with "
        ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
      )
    };
  };

  let getOne = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);

    Async.async @@
    (
      switch (Postgres_Result.decode(result)) {
      | Ok({rows: [row]}) => Ok(row)
      | Ok({rows: []}) =>
        Error(
          "No rows found in database "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      | Ok({rows: _}) =>
        Error(
          "Two or more rows found when we were expecting only one "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      | Error(msg) =>
        Sihl.Core.Db.abort(
          "Error happened in DB when decoding result of getOne() msg="
          ++ msg
          ++ " with "
          ++ Sihl.Core.Db.debug(stmt, Some(parameters)),
        )
      }
    );
  };

  let execute = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    let%Async result = query_(connection, stmt, parameters);

    result
    ->Postgres_Result.decode
    ->Belt.Result.map(({rowCount}) =>
        Sihl.Core.Db.Result.Execution.make(rowCount)
      )
    ->Async.async;
  };

  let withTransaction: (t, t => Async.t('a)) => Async.t('a) =
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
  module Config = {
    type t = {
      .
      "user": string,
      "host": string,
      "database": string,
      "password": string,
      "port": int,
      "connectionTimeoutMillis": int,
      "idleTimeoutMillis": int,
      "max": int,
    };
  };

  type connection = Connection.t;
  type handle;
  type t = {
    name: string,
    handle,
  };

  [@bs.module "pg"] [@bs.new] external setup: Config.t => handle = "Pool";

  [@bs.send] external end_: handle => Async.t(unit) = "end";
  [@bs.send] external connect: handle => Async.t(Connection.t) = "connect";

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
        "connectionTimeoutMillis": 0,
        "idleTimeoutMillis": 10000,
        "max": 10,
      });
    Async.async @@ {name: config.dbName, handle};
  };

  let end_ = db => end_(db.handle);
  let connect = db => connect(db.handle);

  let withConnection = (db, f) => {
    let%Async conn = connect(db);
    let%Async result = f(conn);
    let%Async _ = Connection.release(conn);
    Async.async(result);
  };

  module Clean = {
    [@decco]
    type t = {command: string};

    // TODO I think we need more information on how to clean the database. Maybe this should be done by the consumer after all, since we could have multiple schemas and databases, so this cleaning can happen on the repository abstraction level.
    let query = db => {
      Async.async();
    };
  };
  let clean = Clean.query;
};
