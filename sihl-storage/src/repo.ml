open Lwt.Syntax
module StoredFile = Sihl_type.Storage_stored

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val insert_file : file:StoredFile.t -> unit Lwt.t
  val insert_blob : id:string -> blob:string -> unit Lwt.t
  val get_file : id:string -> StoredFile.t option Lwt.t
  val get_blob : id:string -> string option Lwt.t
  val update_file : file:StoredFile.t -> unit Lwt.t
  val update_blob : id:string -> blob:string -> unit Lwt.t
  val delete_file : id:string -> unit Lwt.t
  val delete_blob : id:string -> unit Lwt.t
end

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  let stored_file =
    let encode m =
      let StoredFile.{ file; blob } = m in
      let Sihl_type.Storage_file.{ id; filename; filesize; mime } = file in
      Ok (id, (filename, (filesize, (mime, blob))))
    in
    let decode (id, (filename, (filesize, (mime, blob)))) =
      let ( let* ) = Result.bind in
      let* id =
        id |> Sihl_type.Database.Id.of_bytes |> Result.map Sihl_type.Database.Id.to_string
      in
      let* blob =
        blob
        |> Sihl_type.Database.Id.of_bytes
        |> Result.map Sihl_type.Database.Id.to_string
      in
      let file = Sihl_type.Storage_file.make ~id ~filename ~filesize ~mime in
      Ok (StoredFile.make ~file ~blob)
    in
    Caqti_type.(
      custom
        ~encode
        ~decode
        Caqti_type.(tup2 string (tup2 string (tup2 int (tup2 string string)))))
  ;;

  let insert_request =
    Caqti_request.exec
      stored_file
      {sql|
         INSERT INTO storage_handles (
         uuid,
         filename,
         filesize,
         mime,
         asset_blob
         ) VALUES (
         UNHEX(REPLACE(?, '-', '')),
         ?,
         ?,
         ?,
         UNHEX(REPLACE(?, '-', ''))
         )
         |sql}
  ;;

  let insert_file ~file =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request file
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let update_file_request =
    Caqti_request.exec
      stored_file
      {sql|
         UPDATE storage_handles SET
         filename = $2,
         filesize = $3,
         mime = $4,
         asset_blob = UNHEX(REPLACE($5, '-', ''))
         WHERE
         storage_handles.uuid = UNHEX(REPLACE($1, '-', ''))
         |sql}
  ;;

  let update_file ~file =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_file_request file
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let get_file_request =
    Caqti_request.find_opt
      Caqti_type.string
      stored_file
      {sql|
         SELECT
         uuid,
         filename,
         filesize,
         mime,
         asset_blob
         FROM storage_handles
         WHERE storage_handles.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}
  ;;

  let get_file ~id =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_file_request id
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let delete_file_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
         DELETE FROM storage_handles
         WHERE storage_handles.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}
  ;;

  let delete_file ~id =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_file_request id
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let get_blob_request =
    Caqti_request.find_opt
      Caqti_type.string
      Caqti_type.string
      {sql|
         SELECT
         asset_data
         FROM storage_blobs
         WHERE storage_blobs.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}
  ;;

  let get_blob ~id =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_blob_request id
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let insert_blob_request =
    Caqti_request.exec
      Caqti_type.(tup2 string string)
      {sql|
         INSERT INTO storage_blobs (
         uuid,
         asset_data
         ) VALUES (
         UNHEX(REPLACE(?, '-', '')),
         ?
         )
         |sql}
  ;;

  let insert_blob ~id ~blob =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_blob_request (id, blob)
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let update_blob_request =
    Caqti_request.exec
      Caqti_type.(tup2 string string)
      {sql|
         UPDATE storage_blobs SET
         asset_data = $2
         WHERE
         storage_blobs.uuid = UNHEX(REPLACE($1, '-', ''))
         |sql}
  ;;

  let update_blob ~id ~blob =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_blob_request (id, blob)
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let delete_blob_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
         DELETE FROM storage_blobs
         WHERE
         storage_blobs.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}
  ;;

  let delete_blob ~id =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_blob_request id
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let clean_handles_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
           TRUNCATE storage_handles;
          |sql}
  ;;

  let clean_handles () =
    Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_handles_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let clean_blobs_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
           TRUNCATE storage_blobs;
          |sql}
  ;;

  let clean_blobs () =
    Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_blobs_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let fix_collation =
    Sihl_type.Migration.create_step
      ~label:"fix collation"
      {sql|
         SET collation_server = 'utf8mb4_unicode_ci';
         |sql}
  ;;

  let create_blobs_table =
    Sihl_type.Migration.create_step
      ~label:"create blobs table"
      {sql|
         CREATE TABLE IF NOT EXISTS storage_blobs (
         id BIGINT UNSIGNED AUTO_INCREMENT,
         uuid BINARY(16) NOT NULL,
         asset_data MEDIUMBLOB NOT NULL,
         created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
         updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
         PRIMARY KEY (id),
         CONSTRAINT unique_uuid UNIQUE KEY (uuid)
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
         |sql}
  ;;

  let create_handles_table =
    Sihl_type.Migration.create_step
      ~label:"create handles table"
      {sql|
         CREATE TABLE IF NOT EXISTS storage_handles (
         id BIGINT UNSIGNED AUTO_INCREMENT,
         uuid BINARY(16) NOT NULL,
         filename VARCHAR(255) NOT NULL,
         filesize BIGINT UNSIGNED,
         mime VARCHAR(128) NOT NULL,
         asset_blob BINARY(16) NOT NULL,
         created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
         updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
         PRIMARY KEY (id),
         CONSTRAINT unique_uuid UNIQUE KEY (uuid)
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
         |sql}
  ;;

  let migration () =
    Sihl_type.Migration.(
      empty "storage"
      |> add_step fix_collation
      |> add_step create_blobs_table
      |> add_step create_handles_table)
  ;;

  let register_migration () = MigrationService.register_migration (migration ())

  let register_cleaner () =
    let cleaner () =
      let* () = clean_handles () in
      clean_blobs ()
    in
    Sihl_persistence.Repository.register_cleaner cleaner
  ;;
end

(* TODO [jerben] Implement postgres repo *)
