let ( let* ) = Lwt.bind

let create ~name ~filter =
  let filter_exn handler req =
    let* result = filter handler req in
    match result with
    | Ok res -> res |> Lwt.return
    | Error error -> error |> Http_res.fail |> Lwt.fail
  in
  Opium.Std.Rock.Middleware.create ~name ~filter:filter_exn
