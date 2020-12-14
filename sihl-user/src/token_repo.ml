module Database = Sihl_persistence.Database
module Repository = Sihl_persistence.Repository
module Migration = Sihl_type.Migration
module Migration_state = Sihl_type.Migration_state
module Model = Sihl_type.Token

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val find_opt : value:string -> Sihl_type.Token.t option Lwt.t
  val find_by_id_opt : id:string -> Sihl_type.Token.t option Lwt.t
  val insert : token:Sihl_type.Token.t -> unit Lwt.t
  val update : token:Sihl_type.Token.t -> unit Lwt.t
end

module MariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  open Sihl_type.Token

  let token =
    let ( let* ) = Result.bind in
    let encode m =
      let status = Status.to_string m.status in
      let* id =
        m.id
        |> Uuidm.of_string
        |> Option.map Uuidm.to_bytes
        |> Option.to_result
             ~none:
               (Printf.sprintf
                  "Invalid id %s provided, can not convert string to uuidv4"
                  m.id)
      in
      Ok (id, (m.value, (m.data, (m.kind, (status, (m.expires_at, m.created_at))))))
    in
    let decode (id, (value, (data, (kind, (status, (expires_at, created_at)))))) =
      let* status = Status.of_string status in
      let* id =
        id
        |> Uuidm.of_bytes
        |> Option.map Uuidm.to_string
        |> Option.to_result
             ~none:
               (Printf.sprintf
                  "Invalid id %s provided, can not convert bytes to uuidv4"
                  id)
      in
      Ok { id; value; data; kind; status; expires_at; created_at }
    in
    Caqti_type.(
      custom
        ~encode
        ~decode
        (tup2
           string
           (tup2
              string
              (tup2 (option string) (tup2 string (tup2 string (tup2 ptime ptime)))))))
  ;;

  module Sql = struct
    let find_request =
      Caqti_request.find
        Caqti_type.string
        token
        {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = ?
        |sql}
    ;;

    let find_opt ~value =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_request value |> Lwt.map Database.raise_error)
    ;;

    let find_by_id_request =
      Caqti_request.find
        Caqti_type.string
        token
        {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
    ;;

    let find_by_id_opt ~id =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_by_id_request id |> Lwt.map Database.raise_error)
    ;;

    let insert_request =
      Caqti_request.exec
        token
        {sql|
        INSERT INTO token_tokens (
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7
        )
        |sql}
    ;;

    let insert ~token =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request token |> Lwt.map Database.raise_error)
    ;;

    let update_request =
      Caqti_request.exec
        token
        {sql|
        UPDATE token_tokens
        SET
          token_data = $3,
          token_kind = $4,
          status = $5,
          expires_at = $6,
          created_at = $7
        WHERE token_tokens.token_value = $2
        |sql}
    ;;

    let update ~token =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request token |> Lwt.map Database.raise_error)
    ;;

    let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE token_tokens;"

    let clean () =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request () |> Lwt.map Database.raise_error)
    ;;
  end

  module Migration = struct
    let fix_collation =
      Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"
    ;;

    let create_tokens_table =
      Migration.create_step
        ~label:"create tokens table"
        {sql|
        CREATE TABLE IF NOT EXISTS token_tokens (
         id BIGINT UNSIGNED AUTO_INCREMENT,
         uuid BINARY(16) NOT NULL,
         token_value VARCHAR(128) NOT NULL,
         token_data VARCHAR(1024),
         token_kind VARCHAR(128) NOT NULL,
         status VARCHAR(128) NOT NULL,
         expires_at TIMESTAMP NOT NULL,
         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
         PRIMARY KEY (id),
         CONSTRAINT unqiue_uuid UNIQUE KEY (uuid),
         CONSTRAINT unique_value UNIQUE KEY (token_value)
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        |sql}
    ;;

    let migration () =
      Migration.(empty "tokens" |> add_step fix_collation |> add_step create_tokens_table)
    ;;
  end

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Repository.register_cleaner Sql.clean
  let find_opt = Sql.find_opt
  let find_by_id_opt = Sql.find_by_id_opt
  let insert = Sql.insert
  let update = Sql.update
end
