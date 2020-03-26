module Async = Sihl.Core.Async;

module Result = {
  module Query = {
    [@decco]
    type t = (list(Js.Json.t), Js.Json.t);
    let decode = Sihl.Core.Error.Decco.stringifyDecoder(t_decode);

    module MetaData = {
      [@decco]
      type t = {
        [@decco.key "FOUND_ROWS()"]
        totalCount: int,
      };

      let foundRowsQuery = "SELECT FOUND_ROWS();";
    };
  };

  module Execution = {
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
    let decode = Sihl.Core.Error.Decco.stringifyDecoder(t_decode);
  };
};

module Persistence: Sihl.Core.Db.INTERFACE = {
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
        result->Result.Query.decode->Belt.Result.map(((rows, _)) => rows)
      );
  };
  let query:
    (
      SihlMysql.Sihl.Core.Db.Connection.t,
      ~stmt: string,
      ~parameters: option(Js.Json.t)
    ) =>
    Js.Promise.t(
      Belt.Result.t(SihlMysql.Sihl.Core.Db.Result.Query.t, string),
    ) =
    (connection, ~stmt, ~parameters) => {
      let parameters =
        Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
      let%Async result = Bindings.query_(connection, stmt, parameters);
      let rows =
        result->Result.Query.decode->Belt.Result.map(((rows, _)) => rows);
      let%Async meta =
        Bindings.query_(
          connection,
          Result.Query.MetaData.foundRowsQuery,
          Js.Json.stringArray([||]),
        );
      let meta = meta->Result.Query.decode;
      let totalCount: int =
        switch (meta) {
        | Ok(([row], _)) =>
          switch (
            row
            |> Sihl.Core.Error.Decco.stringifyDecoder(
                 Result.Query.MetaData.t_decode,
               )
          ) {
          | Ok(Result.Query.MetaData.{totalCount}) => totalCount
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
        ->Result.Execution.decode
        ->Belt.Result.map(((Result.Execution.{affectedRows}, _)) =>
            SihlCore.SihlCoreDbCore.Result.Execution.make(affectedRows)
          )
      );
  };
};
