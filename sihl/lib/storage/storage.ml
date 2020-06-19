open Storage_sig
module Service = Storage_service
module Sig = Storage_sig
include Storage_model

let upload_base64 req ~file ~base64 =
  match Core.Container.fetch Service.key with
  | Some (module Service : SERVICE) -> Service.upload_base64 req ~file ~base64
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_file req ~id =
  match Core.Container.fetch Service.key with
  | Some (module Service : SERVICE) -> Service.get_file req ~id
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let update_base64 req ~file ~base64 =
  match Core.Container.fetch Service.key with
  | Some (module Service : SERVICE) -> Service.update_base64 req ~file ~base64
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_data_base64 req ~file =
  match Core.Container.fetch Service.key with
  | Some (module Service : SERVICE) -> Service.get_data_base64 req ~file
  | None ->
      let msg =
        "STORAGE: Could not find storage service, make sure to register one"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg
