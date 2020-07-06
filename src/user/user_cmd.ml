open Base

let ( let* ) = Lwt.bind

let fn ctx args =
  match args with
  | [ "createadmin"; email; password ] ->
      let (module UserService : User_sig.SERVICE) =
        Core.Container.fetch_service_exn User_sig.key
      in
      let* _ =
        UserService.create_admin ctx ~email ~password ~username:None
        |> Lwt.map Result.ok_or_failwith
      in
      Lwt.return @@ Ok ()
  (* TODO think about a way to encapsulate that case
     without stringly typing *)
  | _ -> Lwt.return @@ Error "wrong usage"

let create_admin =
  Cmd.create ~name:"createadmin" ~description:"createadmin <email> <password>"
    ~fn
