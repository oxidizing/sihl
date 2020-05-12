let create_users_table =
  [%rapper
    execute
      {sql|
CREATE TABLE users_users (
  id serial,
  uuid uuid NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  username VARCHAR(128),
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
  token_value VARCHAR(128) NOT NULL,
  token_user INTEGER,
  status VARCHAR(128) NOT NULL,
  kind VARCHAR(128) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (token_value),
  UNIQUE (uuid),
  FOREIGN KEY (token_user) REFERENCES users_users (id)
);
|sql}]

let add_confirmation_template =
  [%rapper
    execute
      {sql|
        INSERT INTO emails_templates (
          uuid,
          label,
          value,
          status
        ) VALUES (
          'fb7aec3f-2178-4166-beb4-79a3a663e093',
          'registration_confirmation',
          'Hi, \n\n Thanks for signing up. \n\n Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token} \n\n Best, \n Josef',
          'active'
        )
|sql}]

let add_password_reset_template =
  [%rapper
    execute
      {sql|
        INSERT INTO emails_templates (
          uuid,
          label,
          value,
          status
        ) VALUES (
          'fb7aec3f-2178-4166-beb4-79a3a663e092',
          'registration_confirmation',
          'Hi, \n\n You requested to reset your password. \n\n Please go to this URL to reset your password: {base_url}/app/password-reset?token={token} \n\n Best, \n Josef',
          'active'
        )
|sql}]

let migration () =
  ( "users",
    [
      ("create users table", create_users_table);
      ("create tokens table", create_tokens_table);
      ("add confirmation email template", add_confirmation_template);
      ("add password reset email template", add_password_reset_template);
    ] )
