open Base

let ( let* ) = Lwt.bind

let request_with_connection () =
  "/mocked-request" |> Uri.of_string |> Cohttp_lwt.Request.make
  |> Opium.Std.Request.create |> Core.Db.request_with_connection

let seed seed_fn =
  let* request = request_with_connection () in
  seed_fn request

let register_services bindings =
  let config =
    Core.Config.Setting.create ~development:[]
      ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
      ~production:[]
  in
  let project = Run.Project.Project.create ~bindings ~config [] [] in
  let* result = Run.Project.Project.start project in
  result |> Result.ok_or_failwith |> Lwt.return

let just_services _ = failwith "TODO"
