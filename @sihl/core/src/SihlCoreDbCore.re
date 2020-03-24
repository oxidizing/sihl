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

module type DATABASE = {
  let setup: Config.t => Database.t;
  let end_: Database.t => unit;
  let connect: Database.t => Js.Promise.t(Connection.t);
  let release: Connection.t => unit;
  let query:
    (Connection.t, ~params: Js.Json.t=?, ~stmt: string) =>
    Js.Promise.t(Belt.Result.t(Result.Query.t, string));
  let execute:
    (Connection.t, ~params: Js.Json.t=?, ~stmt: string) =>
    Js.Promise.t(Belt.Result.t(Result.Execution.t, string));
};

module Make = (Database: DATABASE) => {
  module Connection = {
    let query = Database.query;
    let execute = Database.execute;
    let release = Database.release;
  };
  module Database = {
    let setup = Database.setup;
    let connect = Database.connect;
    let end_ = Database.end_;
  };
};
