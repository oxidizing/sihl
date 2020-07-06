open Base

let ( let* ) = Lwt.bind

let services ctx services ~before_start =
  let* () =
    Core.Container.bind_services ctx services |> Lwt.map Result.ok_or_failwith
  in
  let* () = before_start () in
  Core.Container.start_services ctx |> Lwt.map Result.ok_or_failwith

let test_kernel_services =
  [
    Utils.Random.Service.instance; Log.Service.instance; Config.Service.instance;
  ]

let app ctx ~config ~services:service_bindings =
  let service_bindings =
    List.concat [ test_kernel_services; service_bindings ]
  in
  services ctx service_bindings ~before_start:(fun () ->
      let* () =
        Config.register_config ctx config |> Lwt.map Base.Result.ok_or_failwith
      in
      Data.Migration.run_all ctx |> Lwt.map Base.Result.ok_or_failwith)

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
