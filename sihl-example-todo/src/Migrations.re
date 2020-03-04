module MariaDb = {
  let steps = namespace => [
    (
      1,
      {j|
CREATE TABLE $(namespace)_boards (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  owner BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (owner) REFERENCES users_users(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
    (
      2,
      {j|
CREATE TABLE $(namespace)_issues (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(512),
  board BIGINT UNSIGNED,
  assignee BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  FOREIGN KEY (assignee) REFERENCES users_users(id),
  FOREIGN KEY (board) REFERENCES issues_boards(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
    ),
  ];
  let make = (~namespace) => Sihl.Core.Db.Migration.{namespace, steps};
};
