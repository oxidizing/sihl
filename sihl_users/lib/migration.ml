let create_users_table =
  [%rapper
    execute
      {sql|
CREATE TABLE users_users (
  id serial,
  uuid uuid NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  name VARCHAR(256) NOT NULL,
  username VARCHAR(128),
  phone VARCHAR(128),
  status VARCHAR(128) NOT NULL,
  admin BOOLEAN NOT NULL DEFAULT false,
  confirmed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (uuid),
  UNIQUE (email)
);
|sql}]

let create_tokens_table =
  [%rapper
    execute
      {sql|
CREATE TABLE users_tokens (
  id serial,
  uuid uuid NOT NULL,
  token VARCHAR(128) NOT NULL,
  user_ INTEGER,
  status VARCHAR(128) NOT NULL,
  kind VARCHAR(128) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (token),
  UNIQUE (uuid),
  FOREIGN KEY (user_) REFERENCES users_users (id)
);
|sql}]

let migrations =
  ( "users",
    [
      ("create users table", create_users_table);
      ("create tokens table", create_tokens_table);
    ] )
