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
    type data = list(Js.Json.t);
    type t = (data, meta);
    let make = (data, ~rowCount) => (data, {rowCount: rowCount});
  };
  module Execution = {
    type t = meta;
    let make = rowCount => {rowCount: rowCount};
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
  let t_decode: Js.Json.t => Decco.result(t);
};

module type CONNECTION = {
  type t;
  let query:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Query.t, string));
  let querySimple:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(list(Js.Json.t), string));
  let execute:
    (t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
};

module type PERSISTENCE = {
  module Connection: CONNECTION;
  module Database: {
    type t;
    let setup: Config.t => t;
    let end_: t => unit;
    let withConnection:
      (t, Connection.t => Js.Promise.t('a)) => Js.Promise.t('a);
    let clean: t => Js.Promise.t(unit);
  };
  module Migration: {
    module Status: MIGRATIONSTATUS;
    let setupMigrationStorage: Connection.t => Js.Promise.t(unit);
    let hasMigrationStatus:
      (Connection.t, ~namespace: string) => Js.Promise.t(bool);
    let getMigrationStatus:
      (Connection.t, ~namespace: string) =>
      Js.Promise.t(Belt.Result.t(Status.t, string));
    let upsertMigrationStatus:
      (Connection.t, ~status: Status.t) => Js.Promise.t(unit);
  };
};

exception DatabaseException(string);

let abort = reason => raise(DatabaseException(reason));
