let map = (p, cb) => Js.Promise.then_(a => cb(a)->Js.Promise.resolve, p);

module Bindings = {
  [@bs.module "mysql2/promise"]
  external setup: SihlCoreDbCore.Config.t => SihlCoreDbCore.Database.t =
    "createPool";
  [@bs.send] external end_: SihlCoreDbCore.Database.t => unit = "end";
  [@bs.send]
  external connect:
    SihlCoreDbCore.Database.t => Js.Promise.t(SihlCoreDbCore.Connection.t) =
    "getConnection";
  [@bs.send] external release: SihlCoreDbCore.Connection.t => unit = "release";

  [@bs.send]
  external query_:
    (SihlCoreDbCore.Connection.t, string, Js.Json.t) =>
    Js.Promise.t(Js.Json.t) =
    "query";
};

module Result = {
  module Query = {
    [@decco]
    type t = (list(Js.Json.t), Js.Json.t);
    let decode = SihlCoreError.Decco.stringifyDecoder(t_decode);
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
    let decode = SihlCoreError.Decco.stringifyDecoder(t_decode);
  };
};

module Mysql: SihlCoreDbCore.DATABASE = {
  let setup = Bindings.setup;
  let end_ = pool =>
    try(Bindings.end_(pool)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => SihlCoreLog.error(message, ())
      | None => SihlCoreLog.error("Failed to end pool", ())
      }
    };
  let connect = Bindings.connect;
  let release = connection =>
    try(Bindings.release(connection)) {
    | Js.Exn.Error(e) =>
      switch (Js.Exn.message(e)) {
      | Some(message) => SihlCoreLog.error(message, ())
      | None => SihlCoreLog.error("Failed to release client", ())
      }
    };

  let query = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    Bindings.query_(connection, stmt, parameters)
    ->map(result =>
        result
        ->Result.Query.decode
        ->Belt.Result.map(((rows, _))
            // TODO read rowCount properly
            => SihlCoreDbCore.Result.Query.make(rows, ~rowCount=0))
      );
  };
  let execute = (connection, ~stmt, ~parameters) => {
    let parameters =
      Belt.Option.getWithDefault(parameters, Js.Json.stringArray([||]));
    Bindings.query_(connection, stmt, parameters)
    ->map(result =>
        result
        ->Result.Execution.decode
        ->Belt.Result.map(_
            // TODO read rowCount properly
            => SihlCoreDbCore.Result.Execution.make(0))
      );
  };
};

include SihlCoreDbCore.Make(Mysql);
