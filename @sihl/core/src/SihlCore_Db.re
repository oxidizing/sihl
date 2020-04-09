module Async = SihlCore_Async;

module Bool = {
  let encoder = i => i ? Js.Json.number(1.0) : Js.Json.number(0.0);
  let decoder = j => {
    switch (Js.Json.decodeNumber(j)) {
    | Some(0.0) => Ok(false)
    | Some(1.0) => Ok(true)
    | _ => Decco.error(~path="", "Not a boolean", j)
    };
  };
  [@decco]
  type t = [@decco.codec (encoder, decoder)] bool;
};

let debug = (stmt, parameters) => {
  "for stmt="
  ++ stmt
  ++ Belt.Option.mapWithDefault(parameters, "", parameters =>
       " with params=" ++ Js.Json.stringify(parameters)
     );
};

module Result = {
  type meta = {rowCount: int};
  module Query = {
    type t('a) = (list('a), meta);
    let make = (data, ~rowCount) => (data, {rowCount: rowCount});
    let meta = ((_, meta)) => meta;
    let rows = ((rows, _)) => rows;
  };
  module Execution = {
    type t = meta;
    let make = rowCount => {rowCount: rowCount};
  };
};

module Migration = {
  type t = {
    steps: string => list((int, string)),
    namespace: string,
  };

  let stepsToApply = (migration, currentVersion) => {
    migration.steps(migration.namespace)
    ->Belt.List.sort(((v1, _), (v2, _)) => v1 > v2 ? 1 : (-1))
    ->Belt.List.keep(((v, _)) => v > currentVersion);
  };

  let maxVersion = steps => {
    steps
    ->Belt.List.sort(((v1, _), (v2, _)) => v1 < v2 ? 1 : (-1))
    ->Belt.List.map(((v, _)) => v)
    ->Belt.List.head
    ->Belt.Option.getWithDefault(0);
  };
};

// TODO centralize
exception DatabaseException(string);

let abort = reason => raise(DatabaseException(reason));

module Config = {
  type t = {
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
};

type migration('t) = {
  this: 't,
  version: 't => int,
  namespace: 't => string,
  dirty: 't => bool,
  setVersion: ('t, ~newVersion: int) => 't,
  t_decode: Js.Json.t => Belt.Result.t('t, string),
};

type connection('t, 'migration) = {
  this: 't,
  raw:
    ('t, ~stmt: string, ~parameters: option(Js.Json.t)) => Async.t(Js.Json.t),
  getMany:
    ('t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Async.t(Belt.Result.t(Result.Query.t(Js.Json.t), string)),
  getOne:
    ('t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Async.t(Belt.Result.t(Js.Json.t, string)),
  execute:
    ('t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Async.t(Belt.Result.t(Result.Execution.t, string)),
  release: 't => Async.t(unit),
  setupMigration: 't => Async.t(Belt.Result.t(Result.Execution.t, string)),
  hasMigration: ('t, ~namespace: string) => Async.t(bool),
  getMigration:
    ('t, ~namespace: string) =>
    Async.t(Belt.Result.t(migration('migration), string)),
  upsertMigration:
    ('t, ~status: 'migration) =>
    Async.t(Belt.Result.t(Result.Execution.t, string)),
  makeMigration: (~namespace: string) => migration('migration),
};

type database('t, 'connection, 'migration) = {
  this: 't,
  end_: 't => Async.t(unit),
  connect: 't => Async.t(connection('connection, 'migration)),
  clean: 't => Async.t(unit),
};

type persistence('database, 'connection, 'migration) = {
  setup:
    SihlCore_Config.Db.Url.t =>
    Async.t(database('database, 'connection, 'migration)),
};
