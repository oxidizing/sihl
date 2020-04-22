open Core
open Sihl_core.My_command
open Sihl_core.Fail

let ( let* ) = Lwt.bind

let fn request args description =
  match args with
  | [ "createadmin"; email; password ] -> (
      let* result =
        try_to_run (fun () ->
            Service.User.create_admin request ~email ~password ~username:"admin"
              ~name:"admin")
      in
      match result with
      | Ok _ -> Lwt.return ()
      | Error error ->
          Lwt.return
          @@ Logs.info (fun m ->
                 m "Failed to run command: %s" (Error.show error)) )
  | _ -> Lwt.return @@ Logs.info (fun m -> m "Usage: %s" description)

let create_admin =
  { name = "createadmin"; description = "createadmin <email> <password>"; fn }
