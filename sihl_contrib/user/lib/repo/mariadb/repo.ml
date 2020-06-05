module Sql = struct
  (* TODO move to some common mariadb namespace *)
  let set_fk_check connection status =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.bool
        {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
    in
    Connection.exec request status

  module User = struct
    module Model = struct
      open Sihl.User

      let t =
        let encode m =
          Ok
            ( m.id,
              ( m.email,
                (m.username, (m.password, (m.status, (m.admin, m.confirmed))))
              ) )
        in
        let decode
            (id, (email, (username, (password, (status, (admin, confirmed))))))
            =
          Ok { id; email; username; password; status; admin; confirmed }
        in
        Caqti_type.(
          custom ~encode ~decode
            (tup2 string
               (tup2 string
                  (tup2 (option string)
                     (tup2 string (tup2 string (tup2 bool bool)))))))
    end

    let get_all connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          email,
          username,
          password,
          status,
          admin,
          confirmed
        FROM user_users
           |sql}
      in
      Connection.collect_list request ()

    let get connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          email,
          username,
          password,
          status,
          admin,
          confirmed
        FROM user_users
        WHERE user_users.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
      in
      Connection.find request

    let get_by_email connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          email,
          username,
          password,
          status,
          admin,
          confirmed
        FROM user_users
        WHERE user_users.email = ?
        |sql}
      in
      Connection.find request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        ) ON DUPLICATE KEY UPDATE
        email = VALUES(email),
        username = VALUES(username),
        password = VALUES(password),
        status = VALUES(status),
        admin = VALUES(admin),
        confirmed = VALUES(confirmed)
        |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit {sql|
TRUNCATE user_users;
|sql}
      in
      Connection.exec request ()
  end

  module Token = struct
    module Model = struct
      open Sihl_user.Model.Token

      let t =
        let encode m = Ok (m.id, (m.value, (m.kind, (m.user, m.status)))) in
        let decode (id, (value, (kind, (user, status)))) =
          Ok { id; value; kind; user; status }
        in
        Caqti_type.(
          custom ~encode ~decode
            (tup2 string (tup2 string (tup2 string (tup2 string string)))))
    end

    let get connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(user_tokens.uuid), 1, 8), '-',
           SUBSTR(HEX(user_tokens.uuid), 9, 4), '-',
           SUBSTR(HEX(user_tokens.uuid), 13, 4), '-',
           SUBSTR(HEX(user_tokens.uuid), 17, 4), '-',
           SUBSTR(HEX(user_tokens.uuid), 21)
           )),
          user_tokens.token_value,
          user_tokens.kind,
          LOWER(CONCAT(
           SUBSTR(HEX(user_users.uuid), 1, 8), '-',
           SUBSTR(HEX(user_users.uuid), 9, 4), '-',
           SUBSTR(HEX(user_users.uuid), 13, 4), '-',
           SUBSTR(HEX(user_users.uuid), 17, 4), '-',
           SUBSTR(HEX(user_users.uuid), 21)
           )),
          user_tokens.status
        FROM user_tokens
        LEFT JOIN user_users
        ON user_users.id = user_tokens.token_user
        WHERE user_tokens.token_value = ?
        |sql}
      in
      Connection.find request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO user_tokens (
          uuid,
          token_value,
          kind,
          token_user,
          status
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          (SELECT id FROM user_users WHERE user_users.uuid = UNHEX(REPLACE(?, '-', ''))),
          ?
        ) ON DUPLICATE KEY UPDATE
        token_value = VALUES(token_value),
        kind = VALUES(kind),
        token_user = VALUES(token_user),
        status = VALUES(status)
        |sql}
      in
      Connection.exec request

    let delete_by_user connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.string
          {sql|
        DELETE FROM user_tokens
        WHERE user_tokens.token_user =
        (SELECT id FROM user_users
         WHERE user_users.uuid = UNHEX(REPLACE(?, '-', '')))
        |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE user_tokens;
           |sql}
      in
      Connection.exec request ()
  end
end

module User = struct
  let get_all connection = Sql.User.get_all connection

  let get ~id connection = Sql.User.get connection id

  let get_by_email ~email connection = Sql.User.get_by_email connection email

  let insert user connection = Sql.User.upsert connection user

  let update user connection = Sql.User.upsert connection user
end

module Token = struct
  let get ~value connection = Sql.Token.get connection value

  let delete_by_user ~id connection = Sql.Token.delete_by_user connection id

  let insert token connection = Sql.Token.upsert connection token

  let update token connection = Sql.Token.upsert connection token
end

module Migration = struct
  let fix_collation =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
SET collation_connection = 'utf8mb4_unicode_ci';
|sql}

  let create_users_table =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
CREATE TABLE user_users (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  username VARCHAR(128),
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
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
CREATE TABLE user_tokens (
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
  FOREIGN KEY (token_user) REFERENCES user_users (id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

  let add_confirmation_template =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
    INSERT INTO email_templates (
        uuid,
        label,
        content,
        status
    ) VALUES (
        UNHEX(REPLACE('fb7aec3f-2178-4166-beb4-79a3a663e093', '-', '')),
        'registration_confirmation',
        'Hi, \n\n Thanks for signing up. \n\n Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token} \n\n Best, \n Josef',
        'active'
    )
|sql}

  let add_password_reset_template =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
    INSERT INTO email_templates (
        uuid,
        label,
        content,
        status
    ) VALUES (
        UNHEX(REPLACE('fb7aec3f-2178-4166-beb4-79a3a663e092', '-', '')),
        'registration_confirmation',
        'Hi, \n\n You requested to reset your password. \n\n Please go to this URL to reset your password: {base_url}/app/password-reset?token={token} \n\n Best, \n Josef',
        'active'
    )
|sql}

  let migration () =
    ( "user",
      [
        ("fix collation", fix_collation);
        ("create users table", create_users_table);
        ("create tokens table", create_tokens_table);
        ("add confirmation email template", add_confirmation_template);
        ("add password reset email template", add_password_reset_template);
      ] )
end

let migrate = Migration.migration

let clean connection =
  let ( let* ) = Lwt_result.bind in
  let* () = Sql.set_fk_check connection false in
  let* () = Sql.User.clean connection in
  let* () = Sql.Token.clean connection in
  Sql.set_fk_check connection true
