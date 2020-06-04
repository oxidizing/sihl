module Sql = struct
  module User = struct
    open Sihl.User

    let get_all =
      [%rapper
        get_many
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string?{username}, 
          @string{password},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        |sql}
          record_out]

    let get =
      [%rapper
        get_one
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string?{username}, 
          @string{password},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        WHERE users_users.uuid = %string{id}
        |sql}
          record_out]

    let get_by_email =
      [%rapper
        get_one
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string?{username}, 
          @string{password},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        WHERE users_users.email = %string{email}
        |sql}
          record_out]

    let insert =
      [%rapper
        execute
          {sql|
        INSERT INTO users_users (
          uuid, 
          email, 
          username, 
          password,
          status,
          admin,
          confirmed
        ) VALUES (
          %string{id}, 
          %string{email}, 
          %string?{username}, 
          %string{password},
          %string{status},
          %bool{admin},
          %bool{confirmed}
        )
        |sql}
          record_in]

    let update =
      [%rapper
        execute
          {sql|
        UPDATE users_users
        SET 
          email = %string{email}, 
          username = %string?{username}, 
          password = %string{password},
          status = %string{status},
          admin = %bool{admin},
          confirmed = %bool{confirmed}
        WHERE users_users.uuid = %string{id}
        |sql}
          record_in]

    let clean =
      [%rapper
        execute {sql|
        TRUNCATE TABLE users_users CASCADE;
        |sql}]
  end

  module Token = struct
    open Sihl_user.Model.Token

    let get =
      [%rapper
        get_one
          {sql|
        SELECT 
          users_tokens.uuid as @string{id}, 
          users_tokens.token_value as @string{value},
          users_users.uuid as @string{user},
          users_tokens.kind as @string{kind},
          users_tokens.status as @string{status}
        FROM users_tokens
        LEFT JOIN users_users 
        ON users_users.id = users_tokens.token_user
        WHERE users_tokens.token_value = %string{value}
        |sql}
          record_out]

    let insert =
      [%rapper
        execute
          {sql|
        INSERT INTO users_tokens (
          uuid, 
          token_value,
          token_user,
          kind,
          status
        ) VALUES (
          %string{id}, 
          %string{value},
          (SELECT id FROM users_users WHERE users_users.uuid = %string{user}),
          %string{kind},
          %string{status}
        )
        |sql}
          record_in]

    let update =
      [%rapper
        execute
          {sql|
        UPDATE users_tokens 
        SET 
          token_value = %string{value},
          token_user = 
          (SELECT id FROM users_users 
           WHERE users_users.uuid = %string{user}),
          kind = %string{kind},
          status = %string{status}
        WHERE users_tokens.uuid = %string{id}
        |sql}
          record_in]

    let delete_by_user =
      [%rapper
        execute
          {sql|
        DELETE FROM users_tokens 
        WHERE users_tokens.token_user = 
        (SELECT id FROM users_users 
         WHERE users_users.uuid = %string{id})
        |sql}]

    let clean =
      [%rapper
        execute {sql|
        TRUNCATE TABLE users_tokens CASCADE;
        |sql}]
  end
end

module Migration = struct
  let create_users_table =
    Sihl.Repo.Migration.Postgresql.migrate
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
|sql}

  let create_tokens_table =
    Sihl.Repo.Migration.Postgresql.migrate
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
|sql}

  let add_confirmation_template =
    Sihl.Repo.Migration.Postgresql.migrate
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
|sql}

  let add_password_reset_template =
    Sihl.Repo.Migration.Postgresql.migrate
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
|sql}

  let migration () =
    ( "users",
      [
        ("create users table", create_users_table);
        ("create tokens table", create_tokens_table);
        ("add confirmation email template", add_confirmation_template);
        ("add password reset email template", add_password_reset_template);
      ] )
end

module User = struct
  let get_all connection = Sql.User.get_all connection ()

  let get ~id connection = Sql.User.get connection ~id

  let get_by_email ~email connection = Sql.User.get_by_email connection ~email

  let insert user connection = Sql.User.insert connection user

  let update user connection = Sql.User.update connection user
end

module Token = struct
  let get ~value connection = Sql.Token.get connection ~value

  let delete_by_user ~id connection = Sql.Token.delete_by_user connection ~id

  let insert token connection = Sql.Token.insert connection token

  let update token connection = Sql.Token.update connection token
end

let migrate = Migration.migration

let clean connection =
  let ( let* ) = Lwt_result.bind in
  let* () = Sql.User.clean connection () in
  Sql.Token.clean connection ()
