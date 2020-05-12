open Base
open Sihl_core.Err

let ( let* ) = Lwt.bind

let fn request args =
  match args with
  | [ "createadmin"; email; password ] -> (
      let* result =
        try_to_run (fun () ->
            Service.User.create_admin request ~email ~password ~username:None)
      in
      Lwt.return
      @@
      match result with
      | Ok _ -> Ok ()
      | Error error ->
          let msg = Error.show error in
          let _ = Logs.info (fun m -> m "Failed to run command: %s" msg) in
          Error msg )
  (* TODO think about a way to encapsulate that case
     without stringly typing *)
  | _ -> Lwt.return @@ Error "wrong usage"

let create_admin =
  Sihl_core.My_command.create ~name:"createadmin"
    ~description:"createadmin <email> <password>" ~fn
