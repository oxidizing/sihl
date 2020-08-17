open Storage_sig
open Storage_model

let ( let* ) = Lwt_result.bind

module Make (Repo : REPO) : SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "storage"
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         Repo.register_cleaner ctx)
        |> Lwt.map Base.Result.ok_or_failwith
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let get_file ctx ~id = Repo.get_file ctx ~id

  let upload_base64 ctx ~file ~base64 =
    let blob_id = Data.Id.random () |> Data.Id.to_string in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) -> Lwt_result.fail msg
      | Ok blob -> Lwt_result.return blob
    in
    let* () = Repo.insert_blob ctx ~id:blob_id ~blob in
    let stored_file = StoredFile.make ~file ~blob:blob_id in
    let* () = Repo.insert_file ctx ~file:stored_file in
    Lwt.return @@ Ok stored_file

  let update_base64 ctx ~file ~base64 =
    let blob_id = StoredFile.blob file in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) -> Lwt_result.fail msg
      | Ok blob -> Lwt_result.return blob
    in
    let* () = Repo.update_blob ctx ~id:blob_id ~blob in
    let* () = Repo.update_file ctx ~file in
    Lwt.return @@ Ok file

  let get_data_base64 ctx ~file =
    let blob_id = StoredFile.blob file in
    let* blob = Repo.get_blob ctx ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) -> Lwt_result.fail msg
    | Some (Ok blob) -> Lwt_result.return @@ Some blob
    | None -> Lwt_result.return None
end

module Repo = struct
  module MakeMariaDb
      (DbService : Data.Db.Sig.SERVICE)
      (RepoService : Data.Repo.Sig.SERVICE)
      (MigrationService : Data.Migration.Sig.SERVICE) : REPO = struct
    let stored_file =
      let encode m =
        let StoredFile.{ file; blob } = m in
        let File.{ id; filename; filesize; mime } = file in
        Ok (id, (filename, (filesize, (mime, blob))))
      in
      let decode (id, (filename, (filesize, (mime, blob)))) =
        let ( let* ) = Result.bind in
        let* id = id |> Data.Id.of_bytes |> Result.map Data.Id.to_string in
        let* blob = blob |> Data.Id.of_bytes |> Result.map Data.Id.to_string in
        let file = File.make ~id ~filename ~filesize ~mime in
        Ok (StoredFile.make ~file ~blob)
      in
      Caqti_type.(
        custom ~encode ~decode
          Caqti_type.(tup2 string (tup2 string (tup2 int (tup2 string string)))))

    let insert_request =
      Caqti_request.exec stored_file
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

    let insert_file ctx ~file =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec insert_request file
          |> Lwt_result.map_err Caqti_error.show)

    let update_file_request =
      Caqti_request.exec stored_file
        {sql|
UPDATE storage_handles SET
  filename = $2,
  filesize = $3,
  mime = $4,
  asset_blob = UNHEX(REPLACE($5, '-', ''))
WHERE
  storage_handles.uuid = UNHEX(REPLACE($1, '-', ''))
|sql}

    let update_file ctx ~file =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec update_file_request file
          |> Lwt_result.map_err Caqti_error.show)

    let get_file_request =
      Caqti_request.find_opt Caqti_type.string stored_file
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

    let get_file ctx ~id =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.find_opt get_file_request id
          |> Lwt_result.map_err Caqti_error.show)

    let get_blob_request =
      Caqti_request.find_opt Caqti_type.string Caqti_type.string
        {sql|
SELECT
  asset_data
FROM storage_blobs
WHERE storage_blobs.uuid = UNHEX(REPLACE(?, '-', ''))
|sql}

    let get_blob ctx ~id =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.find_opt get_blob_request id
          |> Lwt_result.map_err Caqti_error.show)

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

    let insert_blob ctx ~id ~blob =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec insert_blob_request (id, blob)
          |> Lwt_result.map_err Caqti_error.show)

    let update_blob_request =
      Caqti_request.exec
        Caqti_type.(tup2 string string)
        {sql|
UPDATE storage_blobs SET
  asset_data = $2
WHERE
  storage_blobs.uuid = UNHEX(REPLACE($1, '-', ''))
|sql}

    let update_blob ctx ~id ~blob =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec update_blob_request (id, blob)
          |> Lwt_result.map_err Caqti_error.show)

    let clean_handles_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_handles;
          |sql}

    let clean_handles connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec clean_handles_request ()
      |> Lwt_result.map_err Caqti_error.show

    let clean_blobs_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_blobs;
          |sql}

    let clean_blobs connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec clean_blobs_request ()
      |> Lwt_result.map_err Caqti_error.show

    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        {sql|
SET collation_server = 'utf8mb4_unicode_ci';
|sql}

    let create_blobs_table =
      Data.Migration.create_step ~label:"create blobs table"
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

    let create_handles_table =
      Data.Migration.create_step ~label:"create handles table"
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

    let migration () =
      Data.Migration.(
        empty "storage" |> add_step fix_collation
        |> add_step create_blobs_table
        |> add_step create_handles_table)

    let register_migration ctx = MigrationService.register ctx (migration ())

    let register_cleaner ctx =
      let cleaner ctx =
        let ( let* ) = Lwt_result.bind in
        let* () = Data.Db.set_fk_check ~check:false |> DbService.query ctx in
        let* () = clean_handles |> DbService.query ctx in
        let* () = clean_blobs |> DbService.query ctx in
        Data.Db.set_fk_check ~check:true |> DbService.query ctx
      in
      RepoService.register_cleaner ctx cleaner
  end

  (** TODO Implement postgres repo **)
end
