module Env = {
  let get: unit => Js.Json.t = [%raw {| function() { return process.env; } |}];
};

module Db = {
  [@decco]
  type url = {
    [@decco.key "DATABASE_URL"]
    url: string,
  };

  type t = {
    dbUser: string,
    dbHost: string,
    dbName: string,
    dbPassword: string,
    dbPort: string,
    queueLimit: string,
    connectionLimit: string,
  };

  let readDatabaseUrl = () => {
    Env.get() |> url_decode;
  };

  let make = (~user, ~host, ~db, ~password, ~port) => {
    {
      dbUser: user,
      dbHost: host,
      dbName: db,
      dbPassword: password,
      dbPort: port,
      queueLimit: "300",
      connectionLimit: "8",
    };
  };
};

let get = _ => "";
