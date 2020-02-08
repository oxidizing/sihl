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
    Sihl.Core.Log.info("Reading configuration", ());
    let _ =
      Sihl.Core.Config.Db.read()
      |> Tablecloth.Result.map(Database.pool)
      |> Tablecloth.Result.map(App.Http.routes)
      |> Tablecloth.Result.map(
           Sihl.Core.Http.Adapter.startServer(~port=3000),
         );
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

Server.start();
