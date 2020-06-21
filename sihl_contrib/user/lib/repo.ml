module type REPOSITORY = sig
  include Sihl.Sig.REPO

  module User : sig
    val get_all :
      Sihl.Core.Db.connection -> Sihl.User.t list Sihl.Core.Db.db_result

    val get :
      id:string -> Sihl.Core.Db.connection -> Sihl.User.t Sihl.Core.Db.db_result

    val get_by_email :
      email:string ->
      Sihl.Core.Db.connection ->
      Sihl.User.t Sihl.Core.Db.db_result

    val insert :
      Sihl.User.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

    val update :
      Sihl.User.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
  end

  module Token : sig
    val get :
      value:string ->
      Sihl.Core.Db.connection ->
      Sihl.User.Token.t Sihl.Core.Db.db_result

    val delete_by_user :
      id:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

    val insert :
      Sihl.User.Token.t ->
      Sihl.Core.Db.connection ->
      unit Sihl.Core.Db.db_result

    val update :
      Sihl.User.Token.t ->
      Sihl.Core.Db.connection ->
      unit Sihl.Core.Db.db_result
  end
end

module Token = Sihl.User.Token

module MariaDb = struct
  module Sql = struct
    module Model = Sihl.User

    module User = struct
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
      module Model = Token

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
      Sihl.Migration.create_step ~label:"fix collation"
        {sql|
SET collation_connection = 'utf8mb4_unicode_ci';
|sql}

    let create_users_table =
      Sihl.Migration.create_step ~label:"create users table"
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
      Sihl.Migration.create_step ~label:"create tokens table"
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
      Sihl.Migration.create_step ~label:"create default email templates"
        {sql|
    INSERT INTO email_templates (
        uuid,
        label,
        content_text,
        content_html,
        status
    ) VALUES (
        UNHEX(REPLACE('fb7aec3f-2178-4166-beb4-79a3a663e093', '-', '')),
        'registration_confirmation',
        'Hi, \n\n Thanks for signing up. \n\n Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token} \n\n Best, \n Josef',
        '',
        'active'
    )
|sql}

    let add_password_reset_template =
      Sihl.Migration.create_step ~label:"create default email templates"
        {sql|
    INSERT INTO email_templates (
        uuid,
        label,
        content_text,
        content_html,
        status
    ) VALUES (
        UNHEX(REPLACE('fb7aec3f-2178-4166-beb4-79a3a663e092', '-', '')),
        'registration_confirmation',
        'Hi, \n\n You requested to reset your password. \n\n Please go to this URL to reset your password: {base_url}/app/password-reset?token={token} \n\n Best, \n Josef',
        '',
        'active'
    )
|sql}

    let migration () =
      Sihl.Migration.(
        empty "users" |> add_step fix_collation
        |> add_step create_users_table
        |> add_step create_tokens_table
        |> add_step add_confirmation_template
        |> add_step add_password_reset_template)
  end

  let migrate = Migration.migration

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Sihl.Repo.set_fk_check connection false in
    let* () = Sql.User.clean connection in
    let* () = Sql.Token.clean connection in
    Sihl.Repo.set_fk_check connection true
end

module PostgreSql = struct
  module Sql = struct
    module Model = Sihl.User

    module User = struct
      let get_all connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.collect Caqti_type.unit Model.t
            {sql|
        SELECT
          uuid as id,
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
          uuid as id,
          email,
          username,
          password,
          status,
          admin,
          confirmed
        FROM user_users
        WHERE user_users.uuid = ?::uuid
        |sql}
        in
        Connection.find request

      let get_by_email connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.find Caqti_type.string Model.t
            {sql|
        SELECT
          uuid as id,
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

      let insert connection =
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
          ?,
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
        in
        Connection.exec request

      let update connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Model.t
            {sql|
        UPDATE user_users
        SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7
        WHERE user_users.uuid = $1
        |sql}
        in
        Connection.exec request

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.unit
            "TRUNCATE TABLE user_users CASCADE;"
        in

        Connection.exec request ()
    end

    module Token = struct
      module Model = Token

      let get connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.find Caqti_type.string Model.t
            {sql|
        SELECT
          user_tokens.uuid as id,
          user_tokens.token_value as value,
          user_tokens.kind as kind,
          user_users.uuid as user,
          user_tokens.status as status
        FROM user_tokens
        LEFT JOIN user_users
        ON user_users.id = user_tokens.token_user
        WHERE user_tokens.token_value = ?
        |sql}
        in
        Connection.find request

      let insert connection =
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
          ?,
          ?,
          ?,
          (SELECT id FROM user_users WHERE user_users.uuid = ?),
          ?
        )
        |sql}
        in
        Connection.exec request

      let update connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Model.t
            {sql|
        UPDATE user_tokens
        SET
          token_value = $2,
          token_user =
          (SELECT id FROM user_users
           WHERE user_users.uuid = $4),
          kind = $3,
          status = $5
        WHERE user_tokens.uuid = $1
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
         WHERE user_users.uuid = ?)
        |sql}
        in
        Connection.exec request

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.unit
            "TRUNCATE TABLE user_tokens CASCADE;"
        in
        Connection.exec request ()
    end
  end

  module Migration = struct
    let create_users_table =
      Sihl.Migration.create_step ~label:"create users table"
        {sql|
CREATE TABLE user_users (
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
      Sihl.Migration.create_step ~label:"create tokens table"
        {sql|
CREATE TABLE user_tokens (
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
  FOREIGN KEY (token_user) REFERENCES user_users (id)
);
|sql}

    (* TODO this should be a seed that this app call on startup *)
    let add_confirmation_template =
      Sihl.Migration.create_step ~label:"create default email templates"
        {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          content_text,
          content_html,
          status
        ) VALUES (
          'fb7aec3f-2178-4166-beb4-79a3a663e093',
          'registration_confirmation',
          'Hi, \n\n Thanks for signing up. \n\n Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token} \n\n Best, \n Josef',
          '',
          'active'
        )
|sql}

    (* TODO this should be a seed that this app call on startup *)
    let add_password_reset_template =
      Sihl.Migration.create_step ~label:"create default email templates"
        {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          content_text,
          content_html,
          status
        ) VALUES (
          'fb7aec3f-2178-4166-beb4-79a3a663e092',
          'registration_confirmation',
          'Hi, \n\n You requested to reset your password. \n\n Please go to this URL to reset your password: {base_url}/app/password-reset?token={token} \n\n Best, \n Josef',
          '',
          'active'
        )
|sql}

    let migration () =
      Sihl.Migration.(
        empty "users"
        |> add_step create_users_table
        |> add_step create_tokens_table
        |> add_step add_confirmation_template
        |> add_step add_password_reset_template)
  end

  module User = struct
    let get_all connection = Sql.User.get_all connection

    let get ~id connection = Sql.User.get connection id

    let get_by_email ~email connection = Sql.User.get_by_email connection email

    let insert user connection = Sql.User.insert connection user

    let update user connection = Sql.User.update connection user
  end

  module Token = struct
    let get ~value connection = Sql.Token.get connection value

    let delete_by_user ~id connection = Sql.Token.delete_by_user connection id

    let insert token connection = Sql.Token.insert connection token

    let update token connection = Sql.Token.update connection token
  end

  let migrate = Migration.migration

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Sql.User.clean connection in
    Sql.Token.clean connection
end
