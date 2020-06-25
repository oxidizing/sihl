open Base

let ( let* ) = Lwt.bind

let request_with_connection () =
  "/mocked-request" |> Uri.of_string |> Cohttp_lwt.Request.make
  |> Opium.Std.Request.create |> Core.Db.request_with_connection

let register_services services =
  let config =
    Core.Config.Setting.create ~development:[]
      ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
      ~production:[]
  in
  let project = Run.Project.Project.create ~services ~config [] [] in
  let* result = Run.Project.Project.start project in
  let () = result |> Result.ok_or_failwith in
  let* result = Run.Project.Project.clean project in
  result |> Result.ok_or_failwith |> Lwt.return

let seed seed_fn =
  let* request = request_with_connection () in
  let* result = seed_fn request in
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> failwith ("Failed to run seed " ^ msg)

let context ?user () =
  let pool = Core.Db.connect () |> Result.ok_or_failwith in
  match user with
  | Some user ->
      Core.Ctx.(empty |> User.ctx_add_user user |> Core.Db.ctx_add_pool pool)
  | None -> Core.Ctx.(empty |> Core.Db.ctx_add_pool pool)
