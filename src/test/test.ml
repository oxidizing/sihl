open Base

let ( let* ) = Lwt.bind

let with_services ctx services =
  Core.Container.bind_services ctx services |> Lwt.map Result.ok_or_failwith

(* let config =
 *   Config.create ~development:[]
 *     ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
 *     ~production:[]
 * in
 * let project = Run.Project.Project.create ~services ~config [] [] in
 * let* result = Run.Project.Project.start project in
 * let () = result |> Result.ok_or_failwith in
 * let* result = Run.Project.Project.clean project in
 * result |> Result.ok_or_failwith |> Lwt.return *)

let seed seed_fn =
  let ctx = Data.Db.ctx_with_pool () in
  let* result = seed_fn ctx in
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> failwith ("Failed to run seed " ^ msg)

let context ?user () =
  match user with
  | Some user -> Data.Db.ctx_with_pool () |> User.ctx_add_user user
  | None -> Data.Db.ctx_with_pool ()

let start_app _ = failwith "TODO start_app"

let stop_app () = failwith "TODO stop_app"

let clean () = failwith "TODO clean()"

let migrate () = failwith "TODO migrate()"
