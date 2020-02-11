module Async = Sihl.Core.Async;

module Database = {
  let pool = (config: Sihl.Core.Config.Db.t) =>
    Sihl.Core.Db.Mysql.pool({
      "user": config.dbUser,
      "host": config.dbHost,
      "database": config.dbName,
      "password": config.dbPassword,
      "port": config.dbPort,
      "waitForConnections": true,
      "connectionLimit": config.connectionLimit,
      "queueLimit": config.queueLimit,
    });
};

module Server = {
  let start = config => {
    Sihl.Core.Log.info("Starting app " ++ App.Settings.name, ());
    let config =
      Sihl.Core.Config.Db.read()
      |> Sihl.Core.Error.Decco.stringifyResult
      |> Sihl.Core.Error.failIfError;
    let pool = config |> Database.pool;
    let routes = pool |> App.Http.routes;
    Sihl.Core.Http.application(~port=3000, routes) |> ignore;
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

Server.start();
