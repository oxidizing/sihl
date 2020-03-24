module Types = {
  module Result = {
    type meta = {rowCount: int};

    module Query = {
      type data = list(Js.Json.t);
      type t = (data, meta);
    };
    module Execution = {
      type t = meta;
    };
  };

  module Trx = {
    type trx;
    type t = {
      query:
        (trx, string, Js.Json.t) =>
        Js.Promise.t(Belt.Result.t(Result.Query.t, string)),
      execute:
        (trx, string, Js.Json.t) =>
        Js.Promise.t(Belt.Result.t(Result.Execution.t, string)),
    };
  };

  module Connection = {
    type connection;
    type t = {
      this: connection,
      query:
        (connection, string, Js.Json.t) =>
        Js.Promise.t(Belt.Result.t(Result.Query.t, string)),
      execute:
        (connection, string, Js.Json.t) =>
        Js.Promise.t(Belt.Result.t(Result.Execution.t, string)),
    };
  };

  module Database = {
    type database;
    type t = {
      this: database,
      connect: database => Connection.t,
    };
  };
};

module Mysql = {
  module Connection = {
    external query:
      (Types.Connection.connection, string, Js.Json.t) =>
      Js.Promise.t(Belt.Result.t(Types.Result.Query.t, string)) =
      "query";
    external execute:
      (Types.Connection.connection, string, Js.Json.t) =>
      Js.Promise.t(Belt.Result.t(Types.Result.Execution.t, string)) =
      "execute";
  };

  module Database = {
    external _connect: Types.Database.database => Types.Connection.connection =
      "connect";

    let connect = database => {
      let connection = _connect(database);
      Types.Connection.{
        this: connection,
        query: Connection.query,
        execute: Connection.execute,
      };
    };
    external make: (string, string) => Types.Database.database = "db";
  };

  let setup = (port, host) => {
    let database = Database.make(port, host);
    Types.Database.{this: database, connect: Database.connect};
  };
};

module User = {
  module Async = SihlCoreAsync;

  let app = () => {
    let database = Mysql.setup("3000", "localhost");
    let connection = database.connect(database.this);
    let%Async result =
      connection.query(
        connection.this,
        "some stmt",
        Js.Json.string("some param"),
      );
    Async.async();
  };
};
