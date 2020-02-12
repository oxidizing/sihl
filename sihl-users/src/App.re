module Settings = {
  let name = "User Management App";
  let prefix = "users";
  let minPasswordLength = 8;
};

module Database = {
  let clean = [Repository.User.Clean.run];
  let migrations = prefix => [
    {j|
CREATE TABLE IF NOT EXISTS $(prefix)_users (
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
  ];
};

module Http = {
  // TODO get connection and inject it into routes
  let routes = database => [
    Routes.GetUser.endpoint(database),
    Routes.GetUsers.endpoint(database),
  ];
};
