open Lwt.Syntax
module Database = Sihl_persistence.Database
module Cleaner = Sihl_core.Cleaner
module Migration = Sihl_facade.Migration
module Model = Sihl_contract.User

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val lifecycles : Sihl_core.Container.Lifecycle.t list

  val search
    :  [< `Desc | `Asc ]
    -> string option
    -> int
    -> (Model.t list * int) Lwt.t

  val get : id:string -> Model.t option Lwt.t
  val get_by_email : email:string -> Model.t option Lwt.t
  val insert : user:Model.t -> unit Lwt.t
  val update : user:Model.t -> unit Lwt.t
end

let user =
  let open Sihl_contract.User in
  let encode m =
    Ok
      ( m.id
      , ( m.email
        , ( m.username
          , ( m.password
            , (m.status, (m.admin, (m.confirmed, (m.created_at, m.updated_at))))
            ) ) ) )
  in
  let decode
      ( id
      , ( email
        , ( username
          , (password, (status, (admin, (confirmed, (created_at, updated_at)))))
          ) ) )
    =
    Ok
      { id
      ; email
      ; username
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
                  string
                  (tup2 string (tup2 bool (tup2 bool (tup2 ptime ptime)))))))))
;;

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Database.lifecycle; Cleaner.lifecycle; MigrationService.lifecycle ]
  ;;

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
      Sihl_facade.Migration.create_step
        ~label:"add updated_at column"
        {sql|
ALTER TABLE user_users
ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
|sql}
    ;;

    let migration () =
      Migration.(
        empty "user"
        |> add_step fix_collation
        |> add_step create_users_table
        |> add_step add_updated_at_column)
    ;;
  end

  let filter_fragment =
    {sql|
        WHERE user_users.email LIKE $1
          OR user_users.username LIKE $1
          OR user_users.status LIKE $1 |sql}
  ;;

  let search_query =
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
          created_at,
          updated_at
        FROM user_users |sql}
  ;;

  let requests =
    Sihl_persistence.Database.prepare_requests
      search_query
      filter_fragment
      "id"
      user
  ;;

  let found_rows_request =
    Caqti_request.find
      ~oneshot:true
      Caqti_type.unit
      Caqti_type.int
      "SELECT COUNT(*) FROM user_users"
  ;;

  let search sort filter limit =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let* result =
          Sihl_persistence.Database.run_request
            connection
            requests
            sort
            filter
            limit
        in
        let* amount =
          Connection.find found_rows_request () |> Lwt.map Result.get_ok
        in
        Lwt.return (result, amount))
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

  let get ~id =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id |> Lwt.map Database.raise_error)
  ;;

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
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}
  ;;

  let get_by_email ~email =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email
        |> Lwt.map Database.raise_error)
  ;;

  let insert_request =
    Caqti_request.exec
      user
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        ) VALUES (
          UNHEX(REPLACE($1, '-', '')),
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9
        )
        |sql}
  ;;

  let insert ~user =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request user |> Lwt.map Database.raise_error)
  ;;

  let update_request =
    Caqti_request.exec
      user
      {sql|
        UPDATE user_users
        SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7,
          created_at = $8,
          updated_at = $9
        WHERE user_users.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
  ;;

  let update ~user =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request user |> Lwt.map Database.raise_error)
  ;;

  let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE user_users;"

  let clean () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request () |> Lwt.map Database.raise_error)
  ;;

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Database.lifecycle; Cleaner.lifecycle; MigrationService.lifecycle ]
  ;;

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
      Sihl_facade.Migration.create_step
        ~label:"add updated_at column"
        {sql|
ALTER TABLE user_users
ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
|sql}
    ;;

    let migration () =
      Migration.(
        empty "user"
        |> add_step create_users_table
        |> add_step add_updated_at_column)
    ;;
  end

  let filter_fragment =
    {sql|
        WHERE user_users.email LIKE $1
          OR user_users.username LIKE $1
          OR user_users.status LIKE $1 |sql}
  ;;

  let search_query =
    {sql|
        SELECT
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users |sql}
  ;;

  let requests =
    Sihl_persistence.Database.prepare_requests
      search_query
      filter_fragment
      "id"
      user
  ;;

  let found_rows_request =
    Caqti_request.find
      ~oneshot:true
      Caqti_type.unit
      Caqti_type.int
      "SELECT COUNT(*) FROM user_users"
  ;;

  let search sort filter limit =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let* result =
          Sihl_persistence.Database.run_request
            connection
            requests
            sort
            filter
            limit
        in
        let* amount =
          Connection.find found_rows_request () |> Lwt.map Result.get_ok
        in
        Lwt.return (result, amount))
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

  let get ~id =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id |> Lwt.map Database.raise_error)
  ;;

  let get_by_email_request =
    Caqti_request.find_opt
      Caqti_type.string
      user
      {sql|
        SELECT
          uuid as id,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}
  ;;

  let get_by_email ~email =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email
        |> Lwt.map Database.raise_error)
  ;;

  let insert_request =
    Caqti_request.exec
      user
      {sql|
        INSERT INTO user_users (
          uuid,
          email,
          username,
          password,
          status,
          admin,
          confirmed,
          created_at,
          updated_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9
        )
        |sql}
  ;;

  let insert ~user =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request user |> Lwt.map Database.raise_error)
  ;;

  let update_request =
    Caqti_request.exec
      user
      {sql|
        UPDATE user_users
        SET
          email = $2,
          username = $3,
          password = $4,
          status = $5,
          admin = $6,
          confirmed = $7,
          created_at = $8,
          updated_at = $9
        WHERE user_users.uuid = $1
        |sql}
  ;;

  let update ~user =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request user |> Lwt.map Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE user_users CASCADE;"
  ;;

  let clean () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request () |> Lwt.map Database.raise_error)
  ;;

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end
