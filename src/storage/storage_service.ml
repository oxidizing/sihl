open Storage_sig
open Storage_model

let ( let* ) = Lwt_result.bind

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "storage"

module Make (MigrationService : Data.Migration.Sig.SERVICE) (StorageRepo : REPO) :
  SERVICE = struct
  let on_bind ctx =
    let* () = MigrationService.register ctx (StorageRepo.migrate ()) in
    Data.Repo.register_cleaner ctx StorageRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get_file ctx ~id = StorageRepo.get_file ~id |> Data.Db.query ctx

  let upload_base64 ctx ~file ~base64 =
    let blob_id = Data.Id.random () |> Data.Id.to_string in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) -> Lwt_result.fail msg
      | Ok blob -> Lwt_result.return blob
    in
    let* () = StorageRepo.insert_blob ~id:blob_id ~blob |> Data.Db.query ctx in
    let stored_file = StoredFile.make ~file ~blob:blob_id in
    let* () = StorageRepo.insert_file ~file:stored_file |> Data.Db.query ctx in
    Lwt.return @@ Ok stored_file

  let update_base64 ctx ~file ~base64 =
    let ( let* ) = Lwt_result.bind in
    let blob_id = StoredFile.blob file in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) -> Lwt_result.fail msg
      | Ok blob -> Lwt_result.return blob
    in
    let* () = StorageRepo.update_blob ~id:blob_id ~blob |> Data.Db.query ctx in
    let* () = StorageRepo.update_file ~file |> Data.Db.query ctx in
    Lwt.return @@ Ok file

  let get_data_base64 ctx ~file =
    let blob_id = StoredFile.blob file in
    let* blob = StorageRepo.get_blob ~id:blob_id |> Data.Db.query ctx in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) -> Lwt_result.fail msg
    | Some (Ok blob) -> Lwt_result.return @@ Some blob
    | None -> Lwt_result.return None
end

module StorageRepoMariaDb = struct
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

  let insert_file connection ~file =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
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
    in
    Connection.exec request file |> Lwt_result.map_err Caqti_error.show

  let update_file connection ~file =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
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
    in
    Connection.exec request file |> Lwt_result.map_err Caqti_error.show

  let get_file connection ~id =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
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
    in
    Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

  let get_blob connection ~id =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string Caqti_type.string
        {sql|
SELECT
  asset_data
FROM storage_blobs
WHERE storage_blobs.uuid = UNHEX(REPLACE(?, '-', ''))
|sql}
    in
    Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

  let insert_blob connection ~id ~blob =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
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
    in
    Connection.exec request (id, blob) |> Lwt_result.map_err Caqti_error.show

  let update_blob connection ~id ~blob =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup2 string string)
        {sql|
UPDATE storage_blobs SET
  asset_data = $2
WHERE
  storage_blobs.uuid = UNHEX(REPLACE($1, '-', ''))
|sql}
    in
    Connection.exec request (id, blob) |> Lwt_result.map_err Caqti_error.show

  let clean_handles connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_handles;
          |sql}
    in
    Connection.exec request () |> Lwt_result.map_err Caqti_error.show

  let clean_blobs connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_blobs;
          |sql}
    in
    Connection.exec request () |> Lwt_result.map_err Caqti_error.show

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

  let migrate () =
    Data.Migration.(
      empty "storage"
      |> add_step create_blobs_table
      |> add_step create_handles_table)

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Data.Db.set_fk_check connection ~check:false in
    let* () = clean_handles connection in
    let* () = clean_blobs connection in
    Data.Db.set_fk_check connection ~check:true
end

(** TODO Implement postgres repo **)

module MariaDb = Make (Data.Migration.Service.MariaDb) (StorageRepoMariaDb)

let mariadb = Core.Container.create_binding key (module MariaDb) (module MariaDb)
