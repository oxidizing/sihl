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

module Database = {
  type t;
};

module Connection = {
  type t;
};

module type CONNECTION = {
  let release: Connection.t => unit;
  let query:
    (Connection.t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Query.t, string));
  let execute:
    (Connection.t, ~stmt: string, ~parameters: option(Js.Json.t)) =>
    Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
};

module type DATABASE = {
  let setup: Config.t => Database.t;
  let end_: Database.t => unit;
  let connect: Database.t => Js.Promise.t(Connection.t);
};

module type INTERFACE = {
  include DATABASE;
  include CONNECTION;
};

module type PERSISTENCE = {
  module Connection: CONNECTION;
  module Database: DATABASE;
};

module Make = (Database: INTERFACE) : PERSISTENCE => {
  module Connection: CONNECTION = {
    let release = Database.release;
    let query = Database.query;
    let execute = Database.execute;
  };
  module Database: DATABASE = {
    let setup = Database.setup;
    let connect = Database.connect;
    let end_ = Database.end_;
  };
};
