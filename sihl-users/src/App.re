module Settings = {
  let name = "User Management App";
  let namespace = "users";
};

module Database = {
  let clean = [Repository.Token.Clean.run, Repository.User.Clean.run];
  let migrations = namespace => [
    "
SET collation_connection = 'utf8mb4_unicode_ci';
",
    "
CREATE OR REPLACE
  FUNCTION uuid_of(uuid BINARY(16))
  RETURNS VARCHAR(36)
  RETURN LOWER(CONCAT(
  SUBSTR(HEX(uuid), 1, 8), '-',
  SUBSTR(HEX(uuid), 9, 4), '-',
  SUBSTR(HEX(uuid), 13, 4), '-',
  SUBSTR(HEX(uuid), 17, 4), '-',
  SUBSTR(HEX(uuid), 21)
));
",
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
  status VARCHAR(128) NOT NULL,
  admin BOOLEAN,
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
  user BIGINT UNSIGNED,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_token UNIQUE KEY (token),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (user) REFERENCES $(namespace)_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
  ];
};

module Http = {
  let routes = database => [
    Routes.Login.endpoint(Settings.namespace, database),
    Routes.Register.endpoint(Settings.namespace, database),
    Routes.GetMe.endpoint(Settings.namespace, database),
    Routes.GetUser.endpoint(Settings.namespace, database),
    Routes.GetUsers.endpoint(Settings.namespace, database),
  ];
};

let app =
  Sihl.Core.Main.App.make(
    ~name="User Management App",
    ~namespace="users",
    ~routes=Http.routes,
    ~clean=[Repository.Token.Clean.run, Repository.User.Clean.run],
    ~migrations=Database.migrations,
  );
