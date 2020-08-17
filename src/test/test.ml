open Base

let ( let* ) = Lwt.bind

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
