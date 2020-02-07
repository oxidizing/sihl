module Settings = {
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
    [@decco.key "DB_CONNECTION_LIMIT"] [@decco.default 8]
    connectionLimit: int,
  };

  let encode = t_encode;
  let decode = t_decode;
};

module Database = {
  let pool = (config: Settings.t) =>
    Sihl.Core.Mysql.pool({
      "user": config.dbUser,
      "host": config.dbHost,
      "database": config.dbName,
      "password": config.dbPassword,
      "port": 3306,
      "waitForConnections": true,
      "connectionLimit": 8,
      "queueLimit": 300,
    });
};

module Server = {
  let start = config => {
    Sihl.Core.Log.info("Starting app " ++ App.Settings.name, ());
    let _ = Sihl.Core.Http.Adapter.startServer(~port=3000, App.Http.routes);
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};

Server.start();
