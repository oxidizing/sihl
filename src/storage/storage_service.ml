open Storage_core
open Lwt.Syntax
module Sig = Storage_service_sig

module Make
    (Log : Log.Service.Sig.SERVICE)
    (Repo : Sig.REPO)
    (DbService : Data.Db.Service.Sig.SERVICE) : Sig.SERVICE = struct
  let find_opt ctx ~id = Repo.get_file ctx ~id

  let find ctx ~id =
    let* file = Repo.get_file ctx ~id in
    match file with
    | None -> raise (Exception ("File not found with id " ^ id))
    | Some file -> Lwt.return file

  let delete ctx ~id =
    let* file = find ctx ~id in
    let blob_id = StoredFile.blob file in
    DbService.atomic ctx (fun ctx ->
        let* () = Repo.delete_file ctx ~id:file.file.id in
        Repo.delete_blob ctx ~id:blob_id)

  let upload_base64 ctx ~file ~base64 =
    let blob_id = Data.Id.random () |> Data.Id.to_string in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
          Log.err (fun m ->
              m "STORAGE: Could not upload base64 content of file %a" File.pp
                file);
          raise (Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.insert_blob ctx ~id:blob_id ~blob in
    let stored_file = StoredFile.make ~file ~blob:blob_id in
    let* () = Repo.insert_file ctx ~file:stored_file in
    Lwt.return stored_file

  let update_base64 ctx ~file ~base64 =
    let blob_id = StoredFile.blob file in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
          Log.err (fun m ->
              m "STORAGE: Could not upload base64 content of file %a"
                StoredFile.pp file);
          raise (Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.update_blob ctx ~id:blob_id ~blob in
    let* () = Repo.update_file ctx ~file in
    Lwt.return file

  let download_data_base64_opt ctx ~file =
    let blob_id = StoredFile.blob file in
    let* blob = Repo.get_blob ctx ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
        Log.err (fun m ->
            m "STORAGE: Could not get base64 content of file %a" StoredFile.pp
              file);
        raise (Exception msg)
    | Some (Ok blob) -> Lwt.return @@ Some blob
    | None -> Lwt.return None

  let download_data_base64 ctx ~file =
    let blob_id = StoredFile.blob file in
    let* blob = Repo.get_blob ctx ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
        Log.err (fun m ->
            m "STORAGE: Could not get base64 content of file %a" StoredFile.pp
              file);
        raise (Exception msg)
    | Some (Ok blob) -> Lwt.return blob
    | None ->
        raise
          (Exception
             (Format.asprintf "File data not found for file %a" StoredFile.pp
                file))

  let start ctx =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.make "storage" ~dependencies:[ Log.lifecycle ]
      ~start ~stop
end

module Repo = struct
  module MakeMariaDb
      (DbService : Data.Db.Service.Sig.SERVICE)
      (RepoService : Data.Repo.Service.Sig.SERVICE)
      (MigrationService : Data.Migration.Service.Sig.SERVICE) : Sig.REPO =
  struct
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
          Connection.exec insert_request file)

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
          Connection.exec update_file_request file)

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
          Connection.find_opt get_file_request id)

    let delete_file_request =
      Caqti_request.exec Caqti_type.string
        {sql|
         DELETE FROM storage_handles
         WHERE storage_handles.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}

    let delete_file ctx ~id =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec delete_file_request id)

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
          Connection.find_opt get_blob_request id)

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
          Connection.exec insert_blob_request (id, blob))

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
          Connection.exec update_blob_request (id, blob))

    let delete_blob_request =
      Caqti_request.exec Caqti_type.string
        {sql|
         DELETE FROM storage_blobs
         WHERE
         storage_blobs.uuid = UNHEX(REPLACE(?, '-', ''))
         |sql}

    let delete_blob ctx ~id =
      DbService.query ctx (fun connection ->
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          Connection.exec delete_blob_request id)

    let clean_handles_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_handles;
          |sql}

    let clean_handles ctx =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_handles_request ())

    let clean_blobs_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
           TRUNCATE storage_blobs;
          |sql}

    let clean_blobs ctx =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_blobs_request ())

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

    let register_migration () = MigrationService.register (migration ())

    let register_cleaner () =
      let cleaner ctx =
        DbService.with_disabled_fk_check ctx (fun ctx ->
            let* () = clean_handles ctx in
            clean_blobs ctx)
      in
      RepoService.register_cleaner cleaner
  end

  (** TODO Implement postgres repo **)
end
