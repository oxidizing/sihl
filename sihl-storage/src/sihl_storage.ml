let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.Storage.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Repo.Sig) : Sihl_contract.Storage.Sig = struct
  let find_opt ~id = Repo.get_file ~id

  let find ~id =
    let open Lwt.Syntax in
    let* file = Repo.get_file ~id in
    match file with
    | None ->
      raise (Sihl_contract.Storage.Exception ("File not found with id " ^ id))
    | Some file -> Lwt.return file
  ;;

  let delete ~id =
    let open Lwt.Syntax in
    let* file = find ~id in
    let blob_id = file.Sihl_contract.Storage.blob in
    let* () = Repo.delete_file ~id:file.file.id in
    Repo.delete_blob ~id:blob_id
  ;;

  let upload_base64 file ~base64 =
    let open Lwt.Syntax in
    let blob_id = Uuidm.v `V4 |> Uuidm.to_string in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
        Logs.err (fun m ->
            m
              "Could not upload base64 content of file %a"
              Sihl_facade.Storage.pp_file
              file);
        raise (Sihl_contract.Storage.Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.insert_blob ~id:blob_id ~blob in
    let stored_file = Sihl_contract.Storage.{ file; blob = blob_id } in
    let* () = Repo.insert_file ~file:stored_file in
    Lwt.return stored_file
  ;;

  let update_base64 file ~base64 =
    let open Lwt.Syntax in
    let blob_id = file.Sihl_contract.Storage.blob in
    let* blob =
      match Base64.decode base64 with
      | Error (`Msg msg) ->
        Logs.err (fun m ->
            m
              "Could not upload base64 content of file %a"
              Sihl_facade.Storage.pp_stored
              file);
        raise (Sihl_contract.Storage.Exception msg)
      | Ok blob -> Lwt.return blob
    in
    let* () = Repo.update_blob ~id:blob_id ~blob in
    let* () = Repo.update_file ~file in
    Lwt.return file
  ;;

  let download_data_base64_opt file =
    let open Lwt.Syntax in
    let blob_id = file.Sihl_contract.Storage.blob in
    let* blob = Repo.get_blob ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
      Logs.err (fun m ->
          m
            "Could not get base64 content of file %a"
            Sihl_facade.Storage.pp_stored
            file);
      raise (Sihl_contract.Storage.Exception msg)
    | Some (Ok blob) -> Lwt.return @@ Some blob
    | None -> Lwt.return None
  ;;

  let download_data_base64 file =
    let open Lwt.Syntax in
    let blob_id = file.Sihl_contract.Storage.blob in
    let* blob = Repo.get_blob ~id:blob_id in
    match Option.map Base64.encode blob with
    | Some (Error (`Msg msg)) ->
      Logs.err (fun m ->
          m
            "Could not get base64 content of file %a"
            Sihl_facade.Storage.pp_stored
            file);
      raise (Sihl_contract.Storage.Exception msg)
    | Some (Ok blob) -> Lwt.return blob
    | None ->
      raise
        (Sihl_contract.Storage.Exception
           (Format.asprintf
              "File data not found for file %a"
              Sihl_facade.Storage.pp_stored
              file))
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()
  let lifecycle = Sihl_core.Container.Lifecycle.create "storage" ~start ~stop

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl_core.Container.Service.create lifecycle
  ;;
end

module MariaDb : Sihl_contract.Storage.Sig =
  Make (Repo.MakeMariaDb (Sihl_persistence.Migration.MariaDb))
