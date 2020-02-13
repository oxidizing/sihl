module Settings = {
  let name = "User Management App";
  // TODO think about how to get that into the repos
  let namespace = "users";
  let minPasswordLength = 8;
};

module Database = {
  let clean = [Repository.User.Clean.run, Repository.Token.Clean.run];
  let migrations = namespace => [
    {j|
CREATE TABLE IF NOT EXISTS $(namespace)_users (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  given_name VARCHAR(128) NOT NULL,
  family_name VARCHAR(128) NOT NULL,
  username VARCHAR(128),
  phone VARCHAR(128),
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_email UNIQUE KEY (email),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    {j|
CREATE TABLE IF NOT EXISTS $(namespace)_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  token VARCHAR(128) NOT NULL,
  user BIGINT UNISGNED,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_token UNIQUE KEY (token),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (user) REFERENCES users_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
  ];
  let database = (config: Sihl.Core.Config.Db.t) =>
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

module Http = {
  let routes = database => [
    Routes.GetUser.endpoint(database),
    Routes.GetUsers.endpoint(database),
    Routes.GetMe.endpoint(database),
    Routes.Login.endpoint(database),
    Routes.Register.endpoint(database),
  ];
};

module Server = {
  let start = _config => {
    // TODO catch all exceptions (ServerExceptions might get thrown)
    Sihl.Core.Log.info("Starting app " ++ Settings.name, ());
    let config =
      Sihl.Core.Config.Db.read()
      |> Sihl.Core.Error.Decco.stringifyResult
      |> Sihl.Core.Error.failIfError;
    let pool = config |> Database.database;
    let routes = pool |> Http.routes;
    Sihl.Core.Http.application(~port=3000, routes) |> ignore;
    Sihl.Core.Log.info("App started on port 3000", ());
    ();
  };
};
