module File = struct
  type t = { id : string; filename : string; filesize : int; mime : string }
  [@@deriving fields, yojson, show, eq, make]
end

module UploadedFile = struct
  type t = { file : File.t; blob : string }
  [@@deriving fields, yojson, show, eq, make]
end

module type SERVICE = sig
  include Sig.SERVICE

  val upload_base64 :
    Http.Req.t ->
    file:File.t ->
    base64:string ->
    (UploadedFile.t, string) Lwt_result.t

  val update_base64 :
    Http.Req.t ->
    file:UploadedFile.t ->
    base64:string ->
    (UploadedFile.t, string) Lwt_result.t

  val get_data_base64 :
    Http.Req.t -> file:UploadedFile.t -> (string option, string) Lwt_result.t
end

module type REPO = sig
  include Sig.REPO

  val insert_file :
    Core.Db.connection -> file:UploadedFile.t -> unit Core.Db.db_result

  val insert_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result

  val get_blob :
    Core.Db.connection -> id:string -> string option Core.Db.db_result

  val update_file :
    Core.Db.connection -> file:UploadedFile.t -> unit Core.Db.db_result

  val update_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result
end

let key : (module SERVICE) Core_registry.Key.t =
  Core_registry.Key.create "storage.service"

module Make (Repo : REPO) : SERVICE = struct
  let upload_base64 req ~file ~base64 =
    let ( let* ) = Lwt_result.bind in
    let blob_id = Core.Id.random () |> Core.Id.to_string in
    let* () =
      Repo.insert_blob ~id:blob_id ~blob:base64 |> Core.Db.query_db req
    in
    let uploaded_file = UploadedFile.make ~file ~blob:blob_id in
    let* () = Repo.insert_file ~file:uploaded_file |> Core.Db.query_db req in
    Lwt.return @@ Ok uploaded_file

  let update_base64 req ~file ~base64 =
    let ( let* ) = Lwt_result.bind in
    let blob_id = UploadedFile.blob file in
    let* () =
      Repo.update_blob ~id:blob_id ~blob:base64 |> Core.Db.query_db req
    in
    let* () = Repo.update_file ~file |> Core.Db.query_db req in
    Lwt.return @@ Ok file

  let get_data_base64 req ~file =
    let blob_id = UploadedFile.blob file in
    Repo.get_blob ~id:blob_id |> Core.Db.query_db req

  let provide_repo = Some (Repo.clean, Repo.migrate ())
end

module RepoMariaDb = struct
  let uploaded_file =
    let encode m =
      let UploadedFile.{ file; blob } = m in
      let File.{ id; filename; filesize; mime } = file in
      Ok (id, (filename, (filesize, (mime, blob))))
    in
    let decode (id, (filename, (filesize, (mime, blob)))) =
      let file = File.make ~id ~filename ~filesize ~mime in
      Ok (UploadedFile.make ~file ~blob)
    in
    Caqti_type.(
      custom ~encode ~decode
        Caqti_type.(tup2 string (tup2 string (tup2 int (tup2 string string)))))

  let insert_file connection ~file =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec uploaded_file
        {sql|
INSERT INTO storage_handles (
  uuid,
  filename,
  filesize,
  mime,
  asset_blob
) VALUES (
  ?,
  ?,
  ?,
  ?,
  ?
)
|sql}
    in
    Connection.exec request file

  let update_file connection ~file =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec uploaded_file
        {sql|
UPDATE storage_handles SET
  filename = $2,
  filesize = $3,
  mime = $4,
  asset_blob = $5
WHERE
  storage_handles.uuid = UNHEX(REPLACE($1, '-', ''))
|sql}
    in
    Connection.exec request file

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
    Connection.find_opt request id

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
  ?,
  ?
)
|sql}
    in
    Connection.exec request (id, blob)

  let update_blob connection ~id ~blob =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup2 string string)
        {sql|
UPDATE storage_blobs SET
  data = $2
WHERE
  storage_blobs.uuid = UNHEX(REPLACE($1, '-', ''))
|sql}
    in
    Connection.exec request (id, blob)

  let clean_handles connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_handles;
          |sql}
    in
    Connection.exec request ()

  let clean_blobs connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_blobs;
          |sql}
    in
    Connection.exec request ()

  let create_blobs_table =
    Migration.create_step ~label:"create blobs table"
      {sql|
CREATE TABLE IF NOT EXISTS storage_blobs (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  asset_data MEDIUMBLOB NOT NULL,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

  let create_handles_table =
    Migration.create_step ~label:"create handles table"
      {sql|
CREATE TABLE IF NOT EXISTS assets (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  filename VARCHAR(255) NOT NULL,
  filesize BIGINT UNSIGNED,
  mime VARCHAR(128) NOT NULL,
  asset_blob BIGINT UNSIGNED NOT NULL,
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

  let migrate () =
    Migration.(
      empty "storage"
      |> add_step create_blobs_table
      |> add_step create_handles_table)

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Repo.set_fk_check connection false in
    let* () = clean_handles connection in
    let* () = clean_blobs connection in
    Repo.set_fk_check connection true
end

(** TODO Implement postgres repo **)

module MariaDb = Make (RepoMariaDb)

let mariadb = Core.Registry.bind key (module MariaDb)

let upload_base64 req ~file ~base64 =
  match Core.Registry.get_opt key with
  | Some (module Service : SERVICE) -> Service.upload_base64 req ~file ~base64
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let update_base64 req ~file ~base64 =
  match Core.Registry.get_opt key with
  | Some (module Service : SERVICE) -> Service.update_base64 req ~file ~base64
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_data_base64 req ~file =
  match Core.Registry.get_opt key with
  | Some (module Service : SERVICE) -> Service.get_data_base64 req ~file
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg
