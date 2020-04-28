module Sql = struct
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
      open Model.User

      let t =
        let encode m =
          Ok
            ( m.id,
              ( m.email,
                ( m.username,
                  ( m.password,
                    (m.name, (m.phone, (m.status, (m.admin, m.confirmed)))) ) )
              ) )
        in
        let decode
            ( id,
              ( email,
                ( username,
                  (password, (name, (phone, (status, (admin, confirmed))))) ) )
            ) =
          let _ = Logs.info (fun m -> m "received user with id %s" id) in
          Ok
            {
              id;
              email;
              username;
              password;
              name;
              phone;
              status;
              admin;
              confirmed;
            }
        in
        Caqti_type.(
          custom ~encode ~decode
            (tup2 string
               (tup2 string
                  (tup2 string
                     (tup2 string
                        (tup2 string
                           (tup2 (option string) (tup2 string (tup2 bool bool)))))))))
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
          name,
          phone,
          status,
          admin,
          confirmed
        FROM users_users
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
          name,
          phone,
          status,
          admin,
          confirmed
        FROM users_users
        WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))
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
          name,
          phone,
          status,
          admin,
          confirmed
        FROM users_users
        WHERE users_users.email = ?
        |sql}
      in
      Connection.find request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO users_users (
          uuid,
          email,
          username,
          password,
          name,
          phone,
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
          ?,
          ?,
          ?
        ) ON DUPLICATE KEY UPDATE
        email = VALUES(email),
        username = VALUES(username),
        password = VALUES(password),
        name = VALUES(name),
        phone = VALUES(phone),
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
TRUNCATE users_users;
|sql}
      in
      Connection.exec request ()
  end

  module Token = struct
    module Model = struct
      open Model.Token

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
           SUBSTR(HEX(users_tokens.uuid), 1, 8), '-',
           SUBSTR(HEX(users_tokens.uuid), 9, 4), '-',
           SUBSTR(HEX(users_tokens.uuid), 13, 4), '-',
           SUBSTR(HEX(users_tokens.uuid), 17, 4), '-',
           SUBSTR(HEX(users_tokens.uuid), 21)
           )),
          users_tokens.token_value,
          users_tokens.kind,
          LOWER(CONCAT(
           SUBSTR(HEX(users_users.uuid), 1, 8), '-',
           SUBSTR(HEX(users_users.uuid), 9, 4), '-',
           SUBSTR(HEX(users_users.uuid), 13, 4), '-',
           SUBSTR(HEX(users_users.uuid), 17, 4), '-',
           SUBSTR(HEX(users_users.uuid), 21)
           )),
          users_tokens.status
        FROM users_tokens
        LEFT JOIN users_users
        ON users_users.id = users_tokens.token_user
        WHERE users_tokens.token_value = ?
        |sql}
      in
      Connection.find request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO users_tokens (
          uuid,
          token_value,
          kind,
          token_user,
          status
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          (SELECT id FROM users_users WHERE users_users.uuid = UNHEX(REPLACE(?, '-', ''))),
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
        DELETE FROM users_tokens
        WHERE users_tokens.token_user =
        (SELECT id FROM users_users
         WHERE users_users.uuid = UNHEX(REPLACE(?, '-', '')))
        |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE users_tokens;
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

let ( let* ) = Lwt_result.bind

let clean connection =
  let* () = Sql.set_fk_check connection false in
  let* () = Sql.User.clean connection in
  let* () = Sql.Token.clean connection in
  Sql.set_fk_check connection true
