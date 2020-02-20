module Async = SihlCoreAsync;

module Mysql = {
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
};

exception DatabaseException(string);

let abort = reason => raise(DatabaseException(reason));

let pool = Mysql.pool;

module Repo = {
  module Result = {
    module MetaData = {
      [@decco]
      type t = {
        [@decco.key "FOUND_ROWS()"]
        totalCount: int,
      };
    };

    type t('a) = (list('a), MetaData.t);

    let create = (rows, metaData) => (rows, metaData);
    let createWithTotal = (value, totalCount) => (
      value,
      MetaData.{totalCount: totalCount},
    );
    let total = ((_, MetaData.{totalCount})) => totalCount;
    let metaData = ((_, metaData)) => metaData;
    let rows = ((rows, _)) => rows;

    let foundRowsQuery = "SELECT FOUND_ROWS();";
  };

  let debug = (stmt, parameters) => {
    "for stmt="
    ++ stmt
    ++ Belt.Option.mapWithDefault(parameters, "", parameters =>
         " with params=" ++ Js.Json.stringify(parameters)
       );
  };

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result =
      Mysql.Connection.query(~connection, ~stmt, ~parameters);
    Async.async(
      switch (result) {
      | Belt.Result.Ok(([row], _)) =>
        row |> SihlCoreError.Decco.stringifyDecoder(decode)
      | Belt.Result.Ok(([], _)) =>
        Belt.Result.Error(
          "No rows found in database " ++ debug(stmt, parameters),
        )
      | Belt.Result.Ok(_) =>
        Belt.Result.Error(
          "Two or more rows found when we were expecting only one "
          ++ debug(stmt, parameters),
        )
      | Belt.Result.Error(msg) =>
        abort(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ debug(stmt, parameters),
        )
      },
    );
  };

  let getMany = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result =
      Mysql.Connection.query(~connection, ~stmt, ~parameters);
    switch (result) {
    | Belt.Result.Ok((rows, _)) =>
      let result =
        rows
        ->Belt.List.map(SihlCoreError.Decco.stringifyDecoder(decode))
        ->Belt.List.map(result =>
            switch (result) {
            | Belt.Result.Ok(result) => result
            | Belt.Result.Error(msg) =>
              abort(
                "Error happened in DB when getMany() msg="
                ++ msg
                ++ debug(stmt, parameters),
              )
            }
          );
      let%Async meta =
        Mysql.Connection.query(
          ~connection,
          ~stmt=Result.foundRowsQuery,
          ~parameters=None,
        );
      let meta =
        switch (meta) {
        | Belt.Result.Ok(([row], _)) =>
          switch (
            row
            |> SihlCoreError.Decco.stringifyDecoder(Result.MetaData.t_decode)
          ) {
          | Belt.Result.Ok(meta) => meta
          | Belt.Result.Error(_) =>
            abort(
              "Error happened in DB when decoding meta "
              ++ debug(stmt, parameters),
            )
          }
        | _ =>
          abort(
            "Error happened in DB when fetching FOUND_ROWS() "
            ++ debug(stmt, parameters),
          )
        };
      Async.async @@ Result.create(result, meta);
    | Belt.Result.Error(msg) =>
      abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ debug(stmt, parameters),
      )
    };
  };

  let execute = (~parameters=?, connection, stmt) => {
    let%Async rows =
      Mysql.Connection.execute(~connection, ~stmt, ~parameters);
    Async.async(
      switch (rows) {
      | Belt.Result.Ok(_) => ()
      | Belt.Result.Error(msg) =>
        abort(
          "Error happened in DB when getMany() msg="
          ++ msg
          ++ debug(stmt, parameters),
        )
      },
    );
  };
};

module Bool = {
  let encoder = i => i ? Js.Json.number(1.0) : Js.Json.number(0.0);
  let decoder = j => {
    switch (Js.Json.decodeNumber(j)) {
    | Some(0.0) => Belt.Result.Ok(false)
    | Some(1.0) => Belt.Result.Ok(true)
    | _ => Decco.error(~path="", "Not a boolean", j)
    };
  };
  [@decco]
  type t = [@decco.codec (encoder, decoder)] bool;
};

module Connection = Mysql.Connection;
module Database = {
  include Mysql.Pool;

  let make = (config: SihlCoreConfig.Db.t) =>
    Mysql.pool({
      "user": config.dbUser,
      "host": config.dbHost,
      "database": config.dbName,
      "password": config.dbPassword,
      "port": config.dbPort |> int_of_string,
      "waitForConnections": true,
      "connectionLimit": config.connectionLimit |> int_of_string,
      "queueLimit": config.queueLimit |> int_of_string,
    });

  let withConnection = (db, f) => {
    let%Async conn = connect(db);
    f(conn);
  };

  let clean = (fns, db) => {
    withConnection(
      db,
      conn => {
        let%Async _ = Repo.execute(conn, "SET FOREIGN_KEY_CHECKS = 0;");
        let%Async _ = fns->Belt.List.map(f => f(conn))->Async.allInOrder;
        Repo.execute(conn, "SET FOREIGN_KEY_CHECKS = 1;");
      },
    );
  };

  let runMigrations = (namespace, migrations, db) => {
    withConnection(db, conn => {
      namespace
      ->migrations
      ->Belt.List.map(Repo.execute(conn))
      ->Async.allInOrder
    });
  };
};

// taken from caqti make use of GADT
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
