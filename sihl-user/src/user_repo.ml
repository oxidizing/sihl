open Lwt.Syntax
module Database = Sihl_persistence.Database
module Repository = Sihl_persistence.Repository
module Migration = Sihl_type.Migration
module Migration_state = Sihl_type.Migration_state
module Model = Sihl_type.User

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val lifecycles : Sihl_core.Container.Lifecycle.t list
  val get_all : query:Sihl_type.Database.Ql.t -> (Model.t list * int) Lwt.t
  val get : id:string -> Model.t option Lwt.t
  val get_by_email : email:string -> Model.t option Lwt.t
  val insert : user:Model.t -> unit Lwt.t
  val update : user:Model.t -> unit Lwt.t
end

module Dynparam = struct
  type t = Pack : 'a Caqti_type.t * 'a -> t

  let empty = Pack (Caqti_type.unit, ())
  let add t x (Pack (t', x')) = Pack (Caqti_type.tup2 t' t, (x', x))
end

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  let user =
    let open Sihl_type.User in
    let encode m =
      Ok
        ( m.id
        , ( m.email
          , (m.username, (m.password, (m.status, (m.admin, (m.confirmed, m.created_at)))))
          ) )
    in
    let decode
        (id, (email, (username, (password, (status, (admin, (confirmed, created_at)))))))
      =
      Ok { id; email; username; password; status; admin; confirmed; created_at }
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
                 (tup2 string (tup2 string (tup2 bool (tup2 bool ptime))))))))
  ;;

  let lifecycles =
    [ Database.lifecycle; Repository.lifecycle; MigrationService.lifecycle ]
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

    let migration () =
      Migration.(empty "user" |> add_step fix_collation |> add_step create_users_table)
    ;;
  end

  let get_all ~query =
    let fields =
      [ "id"; "email"; "username"; "status"; "admin"; "confirmed"; "created_at" ]
    in
    let filter_fragment, sort_fragment, pagination_fragment, values =
      Sihl_type.Database.Ql.to_sql_fragments fields query
    in
    let rec create_param values param =
      match values with
      | [] -> param
      | value :: values ->
        create_param values (Dynparam.add Caqti_type.string value param)
    in
    let param = create_param values Dynparam.empty in
    let (Dynparam.Pack (pt, pv)) = param in
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
        filter_fragment
        sort_fragment
        pagination_fragment
    in
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request = Caqti_request.collect ~oneshot:true pt user query in
        let* users = Connection.collect_list request pv |> Lwt.map Database.raise_error in
        let request =
          Caqti_request.find
            ~oneshot:true
            Caqti_type.unit
            Caqti_type.int
            "SELECT FOUND_ROWS()"
        in
        let* meta = Connection.find request () |> Lwt.map Database.raise_error in
        Lwt.return (users, meta))
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
          created_at
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
          created_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}
  ;;

  let get_by_email ~email =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email |> Lwt.map Database.raise_error)
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

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Repository.register_cleaner clean
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  open Sihl_type.User

  let user =
    let encode m =
      Ok
        ( m.id
        , ( m.email
          , (m.username, (m.password, (m.status, (m.admin, (m.confirmed, m.created_at)))))
          ) )
    in
    let decode
        (id, (email, (username, (password, (status, (admin, (confirmed, created_at)))))))
      =
      Ok { id; email; username; password; status; admin; confirmed; created_at }
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
                 (tup2 string (tup2 string (tup2 bool (tup2 bool ptime))))))))
  ;;

  let lifecycles =
    [ Database.lifecycle; Repository.lifecycle; MigrationService.lifecycle ]
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

    let migration () = Migration.(empty "user" |> add_step create_users_table)
  end

  let get_all ~query =
    let fields =
      [ "id"; "email"; "username"; "status"; "admin"; "confirmed"; "created_at" ]
    in
    let filter_fragment, sort_fragment, pagination_fragment, values =
      Sihl_type.Database.Ql.to_sql_fragments fields query
    in
    let rec create_param values param =
      match values with
      | [] -> param
      | value :: values ->
        create_param values (Dynparam.add Caqti_type.string value param)
    in
    let param = create_param values Dynparam.empty in
    let (Dynparam.Pack (pt, pv)) = param in
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
        filter_fragment
        sort_fragment
        pagination_fragment
    in
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request = Caqti_request.collect ~oneshot:true pt user query in
        let* users = Connection.collect_list request pv |> Lwt.map Database.raise_error in
        (* TODO Find out best way to get total rows for that query without limit *)
        let meta = List.length users in
        Lwt.return @@ (users, meta))
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
          created_at
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
          created_at
        FROM user_users
        WHERE user_users.email = ?
        |sql}
  ;;

  let get_by_email ~email =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_by_email_request email |> Lwt.map Database.raise_error)
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
          created_at = $8
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

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Repository.register_cleaner clean
end
