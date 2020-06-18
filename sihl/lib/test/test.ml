open Base

let ( let* ) = Lwt.bind

let request_with_connection () =
  "/mocked-request" |> Uri.of_string |> Cohttp_lwt.Request.make
  |> Opium.Std.Request.create |> Core.Db.request_with_connection

let seed seed_fn =
  let* request = request_with_connection () in
  seed_fn request

let register_services _ =
  (* TODO
     1. Register bindings
     2. Run migrations *)
  (* List.map bindings ~f:Core.Registry.Binding.apply |> ignore;
   * Core.Registry.set_initialized () *)
  failwith "TODO"

let just_services _ = failwith "TODO"
