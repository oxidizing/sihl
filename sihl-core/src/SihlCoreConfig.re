module Env = {
  let get: unit => Js.Json.t = [%raw {| function() { return process.env; } |}];
};

module Db = {
  [@decco]
  type t = {
    [@decco.key "DB_USER"]
    dbUser: string,
    [@decco.key "DB_HOST"]
    dbHost: string,
    [@decco.key "DB_NAME"]
    dbName: string,
    [@decco.key "DB_PASSWORD"]
    dbPassword: string,
    [@decco.key "DB_PORT"]
    // TODO implement custom encoder/decoder for int as string
    dbPort: string,
    [@decco.key "DB_QUEUE_LIMIT"] [@decco.default "300"]
    queueLimit: string,
    [@decco.key "DB_CONNECTION_LIMIT"] [@decco.default "8"]
    connectionLimit: string,
  };

  let encode = t_encode;
  let decode = t_decode;

  let read = () => Env.get() |> decode;
};
