open Base
open Core.Err

let ( let* ) = Lwt.bind

let fn ctx args =
  match args with
  | [ "createadmin"; email; password ] -> (
      let (module UserService : User.Sig.SERVICE) =
        Core.Container.fetch_service_exn User.Sig.key
      in
      let* result =
        try_to_run (fun () ->
            UserService.create_admin ctx ~email ~password ~username:None)
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
  Core.Cmd.create ~name:"createadmin"
    ~description:"createadmin <email> <password>" ~fn
