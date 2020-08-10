let ( let* ) = Lwt_result.bind

module MakeMariaDb
    (DbService : Data.Db.Sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE)
    (MigrationService : Data.Migration.Sig.SERVICE) : User_sig.REPOSITORY =
struct
  module Migration = struct
    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        {sql|
SET collation_server = 'utf8mb4_unicode_ci';
|sql}

    let create_users_table =
      Data.Migration.create_step ~label:"create users table"
        {sql|
CREATE TABLE IF NOT EXISTS user_users (
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
        empty "user" |> add_step fix_collation |> add_step create_users_table)
  end

  module Model = User_core.User

  let get_all ctx ~query =
    let fields =
      [
        "id"; "email"; "username"; "status"; "admin"; "confirmed"; "created_at";
      ]
    in
    let filter_fragment, sort_fragment, pagination_fragment, values =
      Data.Ql.to_sql_fragments fields query
    in
    let rec create_param values param =
      match values with
      | [] -> param
      | value :: values ->
          create_param values
            (Data.Repo.Dynparam.add Caqti_type.string value param)
    in
    let param = create_param values Data.Repo.Dynparam.empty in
    let (Data.Repo.Dynparam.Pack (pt, pv)) = param in

    let query =
      Printf.sprintf
        {sql|
        SELECT SQL_CALC_FOUND_ROWS
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
          confirmed,
          created_at
        FROM user_users
        %s
        %s
        %s
           |sql}
        filter_fragment sort_fragment pagination_fragment
    in

    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request = Caqti_request.collect ~oneshot:true pt Model.t query in
        let* users =
          Connection.collect_list request pv
          |> Lwt_result.map_err Caqti_error.show
        in
        let request =
          Caqti_request.find ~oneshot:true Caqti_type.unit Caqti_type.int
            "SELECT FOUND_ROWS()"
        in
        let* meta =
          Connection.find request ()
          |> Lwt_result.map_err Caqti_error.show
          |> Lwt_result.map (fun total -> Data.Repo.Meta.make ~total)
        in
        Lwt_result.return (users, meta))

  let get_request =
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
          confirmed,
          created_at
        FROM user_users
        WHERE user_users.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}

  let get ctx ~id =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id
        |> Lwt_result.map_err Caqti_error.show)

  let get_by_email_request =
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
          confirmed,
          created_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}

  let get_by_email ctx ~email =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email
        |> Lwt_result.map_err Caqti_error.show)

  let insert_request =
    Caqti_request.exec Model.t
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at
        ) VALUES (
          UNHEX(REPLACE($1, '-', '')),
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8
        )
        |sql}

  let insert ctx ~user =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request user
        |> Lwt_result.map_err Caqti_error.show)

  let update_request =
    Caqti_request.exec Model.t
      {sql|
        UPDATE user_users SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7,
          created_at = $8
        WHERE user_users.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}

  let update ctx ~user =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request user
        |> Lwt_result.map_err Caqti_error.show)

  let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE user_users;"

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.exec clean_request () |> Lwt_result.map_err Caqti_error.show

  let register_migration ctx =
    MigrationService.register ctx (Migration.migration ())

  let register_cleaner ctx =
    let cleaner ctx = clean |> DbService.query ctx in
    RepoService.register_cleaner ctx cleaner
end

module MakePostgreSql
    (DbService : Data.Db.Sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE)
    (MigrationService : Data.Migration.Sig.SERVICE) : User_sig.REPOSITORY =
struct
  module Migration = struct
    let create_users_table =
      Data.Migration.create_step ~label:"create users table"
        {sql|
CREATE TABLE IF NOT EXISTS user_users (
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
      Data.Migration.(empty "user" |> add_step create_users_table)
  end

  module Model = User_core.User

  let get_all ctx ~query =
    let fields =
      [
        "id"; "email"; "username"; "status"; "admin"; "confirmed"; "created_at";
      ]
    in
    let filter_fragment, sort_fragment, pagination_fragment, values =
      Data.Ql.to_sql_fragments fields query
    in
    let rec create_param values param =
      match values with
      | [] -> param
      | value :: values ->
          create_param values
            (Data.Repo.Dynparam.add Caqti_type.string value param)
    in
    let param = create_param values Data.Repo.Dynparam.empty in
    let (Data.Repo.Dynparam.Pack (pt, pv)) = param in

    let query =
      Printf.sprintf
        {sql|
        SELECT
          uuid as id,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at
        FROM user_users
        %s
        %s
        %s
        |sql}
        filter_fragment sort_fragment pagination_fragment
    in
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request = Caqti_request.collect ~oneshot:true pt Model.t query in
        let* users =
          Connection.collect_list request pv
          |> Lwt_result.map_err Caqti_error.show
        in
        (* TODO Find out best way to get total rows for that query without limit *)
        Lwt_result.return (users, Data.Repo.Meta.make ~total:(List.length users)))

  let get_request =
    Caqti_request.find_opt Caqti_type.string Model.t
      {sql|
        SELECT
          uuid as id,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at
        FROM user_users
        WHERE user_users.uuid = ?::uuid
        |sql}

  let get ctx ~id =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id
        |> Lwt_result.map_err Caqti_error.show)

  let get_by_email_request =
    Caqti_request.find_opt Caqti_type.string Model.t
      {sql|
        SELECT
          uuid as id,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}

  let get_by_email ctx ~email =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email
        |> Lwt_result.map_err Caqti_error.show)

  let insert_request =
    Caqti_request.exec Model.t
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8
        )
        |sql}

  let insert ctx ~user =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request user
        |> Lwt_result.map_err Caqti_error.show)

  let update_request =
    Caqti_request.exec Model.t
      {sql|
        UPDATE user_users
        SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7,
          created_at = $8
        WHERE user_users.uuid = $1
        |sql}

  let update ctx ~user =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request user
        |> Lwt_result.map_err Caqti_error.show)

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE user_users CASCADE;"

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.exec clean_request () |> Lwt_result.map_err Caqti_error.show

  let register_migration ctx =
    MigrationService.register ctx (Migration.migration ())

  let register_cleaner ctx =
    let cleaner ctx = clean |> DbService.query ctx in
    RepoService.register_cleaner ctx cleaner
end
