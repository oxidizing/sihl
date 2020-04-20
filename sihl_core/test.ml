open Core

let ( let* ) = Lwt.bind

let request_with_connection =
  "/mocked-request" |> Uri.of_string |> Cohttp_lwt.Request.make
  |> Opium.Std.Request.create |> Db.request_with_connection

let seed seeds =
  let* request = request_with_connection in
  let rec apply_seeds seeds request =
    match seeds with
    | [] -> Lwt_result.return ()
    | seed :: seeds ->
        let* _ = seed request in
        apply_seeds seeds request
  in
  let* result = apply_seeds seeds request in
  result |> Result.ok_or_failwith |> Lwt.return
