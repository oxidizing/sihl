module Database = Sihl.Database
module Cleaner = Sihl.Cleaner
module Migration = Sihl.Database.Migration

module Model = struct
  module Data = struct
    type t = (string * string) list [@@deriving yojson]

    let to_string data = data |> to_yojson |> Yojson.Safe.to_string
    let of_string str = str |> Yojson.Safe.from_string |> of_yojson
  end

  module Status = struct
    type t =
      | Active
      | Inactive

    let to_string = function
      | Active -> "active"
      | Inactive -> "inactive"
    ;;

    let of_string str =
      match str with
      | "active" -> Ok Active
      | "inactive" -> Ok Inactive
      | _ -> Error (Printf.sprintf "Invalid token status %s provided" str)
    ;;
  end

  type t =
    { id : string
    ; value : string
    ; data : Data.t
    ; status : Status.t
    ; expires_at : Ptime.t
    ; created_at : Ptime.t
    }

  let t =
    let ( let* ) = Result.bind in
    let encode m =
      let status = Status.to_string m.status in
      let data = Data.to_string m.data in
      Ok (m.id, (m.value, (data, (status, (m.expires_at, m.created_at)))))
    in
    let decode (id, (value, (data, (status, (expires_at, created_at))))) =
      let* status = Status.of_string status in
      let* data = Data.of_string data in
      Ok { id; value; data; status; expires_at; created_at }
    in
    Caqti_type.(
      custom
        ~encode
        ~decode
        (tup2
           string
           (tup2 string (tup2 string (tup2 string (tup2 ptime ptime))))))
  ;;
end

module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val find : ?ctx:(string * string) list -> string -> Model.t Lwt.t
  val find_opt : ?ctx:(string * string) list -> string -> Model.t option Lwt.t
  val find_by_id : ?ctx:(string * string) list -> string -> Model.t Lwt.t
  val insert : ?ctx:(string * string) list -> Model.t -> unit Lwt.t
  val update : ?ctx:(string * string) list -> Model.t -> unit Lwt.t

  module Model = Model
end

module MariaDb (MigrationService : Sihl.Contract.Migration.Sig) : Sig = struct
  let lifecycles = [ Database.lifecycle; MigrationService.lifecycle ]

  module Model = Model

  module Sql = struct
    let find_request =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = ?
      |sql}
      |> Caqti_type.string ->! Model.t
    ;;

    let find ?ctx value = Database.find ?ctx find_request value

    let find_request_opt =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = ?
      |sql}
      |> Caqti_type.string ->? Model.t
    ;;

    let find_opt ?ctx value = Database.find_opt ?ctx find_request_opt value

    let find_by_id_request =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.uuid = UNHEX(REPLACE(?, '-', ''))
      |sql}
      |> Caqti_type.string ->! Model.t
    ;;

    let find_by_id ?ctx id = Database.find ?ctx find_by_id_request id

    let insert_request =
      let open Caqti_request.Infix in
      {sql|
        INSERT INTO token_tokens (
          uuid,
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        ) VALUES (
          UNHEX(REPLACE($1, '-', '')),
          $2,
          $3,
          $4,
          $5,
          $6
        )
      |sql}
      |> Model.t ->. Caqti_type.unit
    ;;

    let insert ?ctx token = Database.exec ?ctx insert_request token

    let update_request =
      let open Caqti_request.Infix in
      {sql|
        UPDATE token_tokens
        SET
          token_data = $3,
          status = $4,
          expires_at = $5,
          created_at = $6
        WHERE token_tokens.token_value = $2
      |sql}
      |> Model.t ->. Caqti_type.unit
    ;;

    let update ?ctx token = Database.exec ?ctx update_request token

    let clean_request =
      let open Caqti_request.Infix in
      "TRUNCATE token_tokens" |> Caqti_type.(unit ->. unit)
    ;;

    let clean ?ctx () = Database.exec ?ctx clean_request ()
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
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        |sql}
    ;;

    let remove_token_kind_column =
      Migration.create_step
        ~label:"remove token kind column"
        "ALTER TABLE token_tokens DROP COLUMN token_kind"
    ;;

    let migration () =
      Migration.(
        empty "tokens"
        |> add_step fix_collation
        |> add_step create_tokens_table
        |> add_step remove_token_kind_column)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner Sql.clean
  let find = Sql.find
  let find_opt = Sql.find_opt
  let find_by_id = Sql.find_by_id
  let insert = Sql.insert
  let update = Sql.update
end

module PostgreSql (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Database.lifecycle; MigrationService.lifecycle ]

  module Model = Model

  module Sql = struct
    let find_request =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = $1::text
      |sql}
      |> Caqti_type.string ->! Model.t
    ;;

    let find ?ctx value = Database.find ?ctx find_request value

    let find_request_opt =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = $1::text
      |sql}
      |> Caqti_type.string ->? Model.t
    ;;

    let find_opt ?ctx value = Database.find_opt ?ctx find_request_opt value

    let find_by_id_request =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.uuid = $1::uuid
      |sql}
      |> Caqti_type.string ->! Model.t
    ;;

    let find_by_id ?ctx id = Database.find ?ctx find_by_id_request id

    let insert_request =
      let open Caqti_request.Infix in
      {sql|
        INSERT INTO token_tokens (
          uuid,
          token_value,
          token_data,
          status,
          expires_at,
          created_at
        ) VALUES (
          $1::uuid,
          $2,
          $3,
          $4,
          $5 AT TIME ZONE 'UTC',
          $6 AT TIME ZONE 'UTC'
        )
      |sql}
      |> Model.t ->. Caqti_type.unit
    ;;

    let insert ?ctx token = Database.exec ?ctx insert_request token

    let update_request =
      let open Caqti_request.Infix in
      {sql|
        UPDATE token_tokens
        SET
          uuid = $1::uuid,
          token_data = $3,
          status = $4,
          expires_at = $5 AT TIME ZONE 'UTC',
          created_at = $6 AT TIME ZONE 'UTC'
        WHERE token_tokens.token_value = $2
      |sql}
      |> Model.t ->. Caqti_type.unit
    ;;

    let update ?ctx token = Database.exec ?ctx update_request token

    let clean_request =
      let open Caqti_request.Infix in
      "TRUNCATE token_tokens CASCADE" |> Caqti_type.(unit ->. unit)
    ;;

    let clean ?ctx () = Database.exec ?ctx clean_request ()
  end

  module Migration = struct
    let create_tokens_table =
      Migration.create_step
        ~label:"create tokens table"
        {sql|
          CREATE TABLE IF NOT EXISTS token_tokens (
            id serial,
            uuid uuid NOT NULL,
            token_value VARCHAR(128) NOT NULL,
            token_data VARCHAR(1024),
            status VARCHAR(128) NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE (uuid),
          UNIQUE (token_value)
          )
        |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
          ALTER TABLE token_tokens
            ALTER COLUMN created_at TYPE TIMESTAMP
        |sql}
    ;;

    let migration () =
      Migration.(
        empty "tokens"
        |> add_step create_tokens_table
        |> add_step remove_timezone)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner Sql.clean
  let find = Sql.find
  let find_opt = Sql.find_opt
  let find_by_id = Sql.find_by_id
  let insert = Sql.insert
  let update = Sql.update
end
