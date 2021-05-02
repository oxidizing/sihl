module Database = Sihl.Database
module Cleaner = Sihl.Cleaner
module Migration = Sihl.Database.Migration
module Model = Sihl.Contract.User

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val lifecycles : Sihl.Container.lifecycle list

  val search
    :  [ `Desc | `Asc ]
    -> string option
    -> limit:int
    -> offset:int
    -> (Model.t list * int) Lwt.t

  val get : string -> Model.t option Lwt.t
  val get_by_email : string -> Model.t option Lwt.t
  val insert : Model.t -> unit Lwt.t
  val update : Model.t -> unit Lwt.t
end

let status =
  let encode m = m |> Model.status_to_string |> Result.ok in
  let decode = Model.status_of_string in
  Caqti_type.(custom ~encode ~decode string)
;;

let user =
  let open Sihl.Contract.User in
  let encode m =
    Ok
      ( m.id
      , ( m.email
        , ( m.username
          , ( m.name
            , ( m.given_name
              , ( m.password
                , ( m.status
                  , (m.admin, (m.confirmed, (m.created_at, m.updated_at))) ) )
              ) ) ) ) )
  in
  let decode
      ( id
      , ( email
        , ( username
          , ( name
            , ( given_name
              , ( password
                , (status, (admin, (confirmed, (created_at, updated_at)))) ) )
            ) ) ) )
    =
    Ok
      { id
      ; email
      ; username
      ; name
      ; given_name
      ; password
      ; status
      ; admin
      ; confirmed
      ; created_at
      ; updated_at
      }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         string
         (tup2
            string
            (tup2
               (option string)
               (tup2
                  (option string)
                  (tup2
                     (option string)
                     (tup2
                        string
                        (tup2 status (tup2 bool (tup2 bool (tup2 ptime ptime)))))))))))
;;

module MakeMariaDb (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Database.lifecycle; MigrationService.lifecycle ]

  module Migration = struct
    let fix_collation =
      Migration.create_step
        ~label:"fix collation"
        {sql|
         SET collation_server = 'utf8mb4_unicode_ci';
         |sql}
    ;;

    let create_users_table =
      Migration.create_step
        ~label:"create users table"
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
    ;;

    let add_updated_at_column =
      Sihl.Database.Migration.create_step
        ~label:"add updated_at column"
        {sql|
         ALTER TABLE user_users
         ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
         |sql}
    ;;

    let add_name_columns =
      Sihl.Database.Migration.create_step
        ~label:"add name columns"
        {sql|
         ALTER TABLE user_users
         ADD COLUMN name VARCHAR(128) NULL,
         ADD COLUMN given_name VARCHAR(128) NULL;
         |sql}
    ;;

    let migration () =
      Migration.(
        empty "user"
        |> add_step fix_collation
        |> add_step create_users_table
        |> add_step add_updated_at_column
        |> add_step add_name_columns)
    ;;
  end

  let filter_fragment =
    {sql|
        WHERE user_users.email LIKE $1
          OR user_users.username LIKE $1
          OR user_users.name LIKE $1
          OR user_users.given_name LIKE $1
          OR user_users.status LIKE $1 |sql}
  ;;

  let search_query =
    {sql|
        SELECT
          COUNT(*) OVER() as total,
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users |sql}
  ;;

  let request =
    Sihl.Database.prepare_search_request
      ~search_query
      ~filter_fragment
      ~sort_by_field:"id"
      user
  ;;

  let search sort filter ~limit ~offset =
    Sihl.Database.run_search_request request sort filter ~limit ~offset
  ;;

  let get_request =
    Caqti_request.find_opt
      Caqti_type.string
      user
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
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE user_users.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
  ;;

  let get id = Database.find_opt get_request id

  let get_by_email_request =
    Caqti_request.find_opt
      Caqti_type.string
      user
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
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE user_users.email LIKE ?
        |sql}
  ;;

  let get_by_email email = Database.find_opt get_by_email_request email

  let insert_request =
    Caqti_request.exec
      user
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        ) VALUES (
          UNHEX(REPLACE($1, '-', '')),
          LOWER($2),
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9,
          $10,
          $11
        )
        |sql}
  ;;

  let insert user = Database.exec insert_request user

  let update_request =
    Caqti_request.exec
      user
      {sql|
        UPDATE user_users
        SET
          email = LOWER($2),
          username = $3,
          name = $4,
          given_name = $5,
          password = $6,
          status = $7,
          admin = $8,
          confirmed = $9,
          created_at = $10,
          updated_at = $11
        WHERE user_users.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
  ;;

  let update user = Database.exec update_request user
  let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE user_users;"
  let clean () = Database.exec clean_request ()

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end

module MakePostgreSql (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Database.lifecycle; MigrationService.lifecycle ]

  module Migration = struct
    let create_users_table =
      Migration.create_step
        ~label:"create users table"
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
    ;;

    let add_updated_at_column =
      Sihl.Database.Migration.create_step
        ~label:"add updated_at column"
        {sql|
         ALTER TABLE user_users
         ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
         |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
         ALTER TABLE user_users
          ALTER COLUMN created_at TYPE TIMESTAMP,
          ALTER COLUMN updated_at TYPE TIMESTAMP;
         |sql}
    ;;

    let add_name_columns =
      Sihl.Database.Migration.create_step
        ~label:"add name columns"
        {sql|
         ALTER TABLE user_users
         ADD COLUMN name VARCHAR(128) NULL,
         ADD COLUMN given_name VARCHAR(128) NULL;
         |sql}
    ;;

    let migration () =
      Migration.(
        empty "user"
        |> add_step create_users_table
        |> add_step add_updated_at_column
        |> add_step remove_timezone
        |> add_step add_name_columns)
    ;;
  end

  let filter_fragment =
    {sql|
        WHERE user_users.email LIKE $1
          OR user_users.username LIKE $1
          OR user_users.name LIKE $1
          OR user_users.given_name LIKE $1
          OR user_users.status LIKE $1 |sql}
  ;;

  let search_query =
    {sql|
        SELECT
          COUNT(*) OVER() as total,
          uuid,
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users |sql}
  ;;

  let request =
    Sihl.Database.prepare_search_request
      ~search_query
      ~filter_fragment
      ~sort_by_field:"id"
      user
  ;;

  let search sort filter ~limit ~offset =
    Sihl.Database.run_search_request request sort filter ~limit ~offset
  ;;

  let get_request =
    Caqti_request.find_opt
      Caqti_type.string
      user
      {sql|
        SELECT
          uuid as id,
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE user_users.uuid = ?::uuid
        |sql}
  ;;

  let get id = Database.find_opt get_request id

  let get_by_email_request =
    Caqti_request.find_opt
      Caqti_type.string
      user
      {sql|
        SELECT
          uuid as id,
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE LOWER(user_users.email) = LOWER(?)
        |sql}
  ;;

  let get_by_email email = Database.find_opt get_by_email_request email

  let insert_request =
    Caqti_request.exec
      user
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          name,
          given_name,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        ) VALUES (
          $1::uuid,
          LOWER($2),
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9,
          $10 AT TIME ZONE 'UTC',
          $11 AT TIME ZONE 'UTC'
        )
        |sql}
  ;;

  let insert user = Database.exec insert_request user

  let update_request =
    Caqti_request.exec
      user
      {sql|
        UPDATE user_users
        SET
          email = LOWER($2),
          username = $3,
          name = $4,
          given_name = $5,
          password = $6,
          status = $7,
          admin = $8,
          confirmed = $9,
          created_at = $10,
          updated_at = $11
        WHERE user_users.uuid = $1::uuid
        |sql}
  ;;

  let update user = Database.exec update_request user

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE user_users CASCADE;"
  ;;

  let clean () = Database.exec clean_request ()

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end
