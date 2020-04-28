let migrate str connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  let request = Caqti_request.exec Caqti_type.unit str in
  Connection.exec request

let fix_collation =
  migrate {sql|
SET collation_connection = 'utf8mb4_unicode_ci';
|sql}

let create_users_table =
  migrate
    {sql|
CREATE TABLE users_users (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  name VARCHAR(256) NOT NULL,
  username VARCHAR(128),
  phone VARCHAR(128),
  status VARCHAR(128) NOT NULL,
  admin BOOLEAN NOT NULL DEFAULT false,
  confirmed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  CONSTRAINT unique_email UNIQUE KEY (email)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
         |sql}

let create_tokens_table =
  migrate
    {sql|
CREATE TABLE users_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  token_value VARCHAR(128) NOT NULL,
  token_user BIGINT UNSIGNED,
  status VARCHAR(128) NOT NULL,
  kind VARCHAR(128) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unqiue_uuid UNIQUE KEY (uuid),
  CONSTRAINT unique_value UNIQUE KEY (token_value),
  FOREIGN KEY (token_user) REFERENCES users_users (id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

let migration () =
  ( "users",
    [
      ("fix collation", fix_collation);
      ("create users table", create_users_table);
      ("create tokens table", create_tokens_table);
    ] )
