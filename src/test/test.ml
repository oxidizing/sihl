open Base

let ( let* ) = Lwt.bind

let with_services ctx services =
  let* () =
    Core.Container.bind_services ctx services |> Lwt.map Result.ok_or_failwith
  in
  Core.Container.start_services ctx |> Lwt.map Result.ok_or_failwith

let seed seed_fn =
  let ctx = Data.Db.ctx_with_pool () in
  let* result = seed_fn ctx in
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> failwith ("Failed to run seed " ^ msg)

let start_app _ = failwith "TODO start_app"

let stop_app () = failwith "TODO stop_app"

let clean () = failwith "TODO clean()"

let migrate () = failwith "TODO migrate()"
