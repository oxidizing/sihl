open Lwt.Syntax

module Make (Repo : Sihl.Storage.Sig.REPO) : Sihl.Storage.Sig.SERVICE = struct
  let find_opt ctx ~id = Repo.get_file ctx ~id

  let find ctx ~id =
    let* file = Repo.get_file ctx ~id in
    match file with
    | None -> raise (Sihl.Storage.Exception ("File not found with id " ^ id))
    | Some file -> Lwt.return file
  ;;

  let delete ctx ~id =
    let* file = find ctx ~id in
    let blob_id = Sihl.Storage.StoredFile.blob file in
    let* () = Repo.delete_file ctx ~id:file.file.id in
    Repo.delete_blob ctx ~id:blob_id
  ;;

  let upload_base64 ctx ~file ~base64 =
    let blob_id = Sihl.Database.Id.random () |> Sihl.Database.Id.to_string in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
        Logs.err (fun m ->
            m
              "STORAGE: Could not upload base64 content of file %a"
              Sihl.Storage.File.pp
              file);
        raise (Sihl.Storage.Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.insert_blob ctx ~id:blob_id ~blob in
    let stored_file = Sihl.Storage.StoredFile.make ~file ~blob:blob_id in
    let* () = Repo.insert_file ctx ~file:stored_file in
    Lwt.return stored_file
  ;;

  let update_base64 ctx ~file ~base64 =
    let blob_id = Sihl.Storage.StoredFile.blob file in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
        Logs.err (fun m ->
            m
              "STORAGE: Could not upload base64 content of file %a"
              Sihl.Storage.StoredFile.pp
              file);
        raise (Sihl.Storage.Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.update_blob ctx ~id:blob_id ~blob in
    let* () = Repo.update_file ctx ~file in
    Lwt.return file
  ;;

  let download_data_base64_opt ctx ~file =
    let blob_id = Sihl.Storage.StoredFile.blob file in
    let* blob = Repo.get_blob ctx ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
      Logs.err (fun m ->
          m
            "STORAGE: Could not get base64 content of file %a"
            Sihl.Storage.StoredFile.pp
            file);
      raise (Sihl.Storage.Exception msg)
    | Some (Ok blob) -> Lwt.return @@ Some blob
    | None -> Lwt.return None
  ;;

  let download_data_base64 ctx ~file =
    let blob_id = Sihl.Storage.StoredFile.blob file in
    let* blob = Repo.get_blob ctx ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
      Logs.err (fun m ->
          m
            "STORAGE: Could not get base64 content of file %a"
            Sihl.Storage.StoredFile.pp
            file);
      raise (Sihl.Storage.Exception msg)
    | Some (Ok blob) -> Lwt.return blob
    | None ->
      raise
        (Sihl.Storage.Exception
           (Format.asprintf
              "File data not found for file %a"
              Sihl.Storage.StoredFile.pp
              file))
  ;;

  let start ctx =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Sihl.Core.Container.Lifecycle.create "storage" ~start ~stop
  let register () = Sihl.Core.Container.Service.create lifecycle
end

module Repo = Repo
