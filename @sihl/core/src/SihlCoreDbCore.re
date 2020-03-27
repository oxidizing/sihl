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

module type MIGRATIONSTATUS = {
  type t;
  let version: t => int;
  let namespace: t => string;
  let dirty: t => bool;
  let setVersion: (t, ~newVersion: int) => t;
  let make: (~namespace: string) => t;
  let t_decode: Js.Json.t => Belt.Result.t(t, string);
};

module type CONNECTION = {
  type t;
  let raw:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Js.Json.t);
  let getMany:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Query.t(Js.Json.t), string));
  let getOne:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Js.Json.t, string));
  let execute:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
};

module type PERSISTENCE = {
  module Connection: CONNECTION;
  module Database: {
    type t;
    let setup: SihlCoreConfig.Db.Url.t => t;
    let end_: t => unit;
    let withConnection:
      (t, Connection.t => Js.Promise.t('a)) => Js.Promise.t('a);
    let clean: t => Js.Promise.t(unit);
  };
  module Migration: {
    module Status: MIGRATIONSTATUS;
    let setup:
      Connection.t => Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
    let has: (Connection.t, ~namespace: string) => Js.Promise.t(bool);
    let get:
      (Connection.t, ~namespace: string) =>
      Js.Promise.t(Belt.Result.t(Status.t, string));
    let upsert:
      (Connection.t, ~status: Status.t) =>
      Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
  };
};

exception DatabaseException(string);

let abort = reason => raise(DatabaseException(reason));
