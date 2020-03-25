module Async = Sihl.Core.Async;

module Result = {
  module Query = {
    [@decco]
    type t = (list(Js.Json.t), Js.Json.t);
    let decode = Sihl.Core.Error.Decco.stringifyDecoder(t_decode);
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

  let query = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    Bindings.query_(connection, stmt, parameters)
    ->Async.mapAsync(result =>
        result
        ->Result.Query.decode
        ->Belt.Result.map(((rows, _))
            // TODO read rowCount properly
            => SihlCore.SihlCoreDbCore.Result.Query.make(rows, ~rowCount=0))
      );
  };
  let execute = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    Bindings.query_(connection, stmt, parameters)
    ->Async.mapAsync(result =>
        result
        ->Result.Execution.decode
        ->Belt.Result.map(_
            // TODO read rowCount properly
            => SihlCore.SihlCoreDbCore.Result.Execution.make(0))
      );
  };
};
