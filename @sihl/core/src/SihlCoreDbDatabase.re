module Async = SihlCoreAsync;

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Repo = SihlCoreDbRepo.Make(Persistence.Connection);

  let parseUrl = url => {
    switch (url |> Js.String.replace("mysql://", "") |> Js.String.split("@")) {
    | [|credentials, hostAndDb|] =>
      switch (Js.String.split(":", credentials)) {
      | [|user, password|] =>
        switch (Js.String.split(":", hostAndDb)) {
        | [|host, portAndDb|] =>
          switch (Js.String.split("/", portAndDb)) {
          | [|port, db|] =>
            Ok(SihlCoreConfig.Db.make(~user, ~password, ~host, ~port, ~db))
          | _ => Error("Invalid database url provided")
          }
        | _ => Error("Invalid database url provided")
        }
      | _ => Error("Invalid database url provided")
      }
    | _ => Error("Invalid database url provided")
    };
  };

  let parseUrlFromEnv = () => {
    switch (SihlCoreConfig.Db.readDatabaseUrl()) {
    | Ok({url}) => parseUrl(url)
    | Error(error) => Error(SihlCoreError.Decco.stringify(error))
    };
  };

  let make = (config: SihlCoreConfig.Db.t) =>
    Persistence.Database.setup({
      "user": config.dbUser,
      "host": config.dbHost,
      "database": config.dbName,
      "password": config.dbPassword,
      "port": config.dbPort |> int_of_string,
      "waitForConnections": true,
      "connectionLimit": config.connectionLimit |> int_of_string,
      "queueLimit": config.queueLimit |> int_of_string,
    });

  let connectWithCfg = () => {
    parseUrlFromEnv() |> SihlCoreError.failIfError |> make;
  };
};
