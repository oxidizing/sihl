module MariaDb = {
  let steps = namespace => [
    (1, "
SET collation_connection = 'utf8mb4_unicode_ci';
"),
    (
      2,
      "
CREATE
  FUNCTION uuid_of(uuid BINARY(16))
  RETURNS VARCHAR(36)
  DETERMINISTIC
  RETURN LOWER(CONCAT(
  SUBSTR(HEX(uuid), 1, 8), '-',
  SUBSTR(HEX(uuid), 9, 4), '-',
  SUBSTR(HEX(uuid), 13, 4), '-',
  SUBSTR(HEX(uuid), 17, 4), '-',
  SUBSTR(HEX(uuid), 21)
));
",
    ),
    (
      3,
      {j|
CREATE TABLE $(namespace)_users (
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
  confirmed BOOLEAN,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_email UNIQUE KEY (email),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
    (
      4,
      {j|
CREATE TABLE $(namespace)_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  token VARCHAR(128) NOT NULL,
  user BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  kind VARCHAR(128) NOT NULL,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_token UNIQUE KEY (token),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (user) REFERENCES $(namespace)_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
  ];
  let make = (~namespace) => Sihl.App.Db.Migration.{namespace, steps};
};
