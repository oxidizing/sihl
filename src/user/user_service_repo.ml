module MariaDb : User_sig.REPOSITORY = struct
  module Migration = struct
    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        {sql|
SET collation_server = 'utf8mb4_unicode_ci';
|sql}

    let create_users_table =
      Data.Migration.create_step ~label:"create users table"
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
         |sql}

    let migration () =
      Data.Migration.(
        empty "users" |> add_step fix_collation |> add_step create_users_table)
  end

  let migrate = Migration.migration

  module Model = User_core.User

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
    Connection.collect_list request () |> Lwt_result.map_err Caqti_error.show

  let get connection ~id =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string Model.t
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
    Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

  let get_by_email connection ~email =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string Model.t
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
    Connection.find_opt request email |> Lwt_result.map_err Caqti_error.show

  let insert connection model =
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
        )
        |sql}
    in
    Connection.exec request model |> Lwt_result.map_err Caqti_error.show

  let update connection model =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Model.t
        {sql|
        UPDATE user_users SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7
        WHERE uuid = $1
        |sql}
    in
    Connection.exec request model |> Lwt_result.map_err Caqti_error.show

  let insert conn ~user = insert conn user

  let update conn ~user = update conn user

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request = Caqti_request.exec Caqti_type.unit "TRUNCATE user_users;" in
    Connection.exec request () |> Lwt_result.map_err Caqti_error.show
end

module PostgreSql : User_sig.REPOSITORY = struct
  module Migration = struct
    let create_users_table =
      Data.Migration.create_step ~label:"create users table"
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

    let migration () =
      Data.Migration.(empty "users" |> add_step create_users_table)
  end

  let migrate = Migration.migration

  module Model = User_core.User

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
    Connection.collect_list request () |> Lwt_result.map_err Caqti_error.show

  let get connection ~id =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string Model.t
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
    Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

  let get_by_email connection ~email =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string Model.t
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
    Connection.find_opt request email |> Lwt_result.map_err Caqti_error.show

  let insert connection ~user =
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
    Connection.exec request user |> Lwt_result.map_err Caqti_error.show

  let update connection ~user =
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
    Connection.exec request user |> Lwt_result.map_err Caqti_error.show

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE user_users CASCADE;"
    in

    Connection.exec request () |> Lwt_result.map_err Caqti_error.show
end
