open Base

let ( let* ) = Lwt.bind

let request_with_connection () =
  "/mocked-request" |> Uri.of_string |> Cohttp_lwt.Request.make
  |> Opium.Std.Request.create |> Core.Db.request_with_connection

let seed seed_fn =
  let* request = request_with_connection () in
  seed_fn request
