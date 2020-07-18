open Base

let ( let* ) = Lwt.bind

module Make (MigrationService : Data.Migration.Sig.SERVICE) = struct
  let services ctx ~config ~services =
    let* () =
      Core.Container.register_services ctx services
      |> Lwt.map Result.ok_or_failwith
    in
    let* () =
      Config.register_config ctx config |> Lwt.map Result.ok_or_failwith
    in
    let* () =
      Core.Container.start_services ctx |> Lwt.map Result.ok_or_failwith
    in
    MigrationService.run_all ctx |> Lwt.map Base.Result.ok_or_failwith
end

let middleware_stack ctx ?handler stack =
  let handler =
    Option.value ~default:(fun _ -> Lwt.return @@ Web.Res.html) handler
  in
  let route = Web.Route.get "" handler in
  let handler = Web.Middleware.apply_stack stack route |> Web.Route.handler in
  let ctx = Web.Req.create_and_add_to_ctx ctx in
  handler ctx

let seed ctx seed_fn =
  let* result = seed_fn ctx in
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> failwith ("Failed to run seed " ^ msg)
