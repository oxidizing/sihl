type t =
  { name : string
  ; filter : Http.Route.handler -> Http.Route.handler
  }
[@@deriving show]

let create ~name filter = { name; filter }

type stack = t list [@@deriving show]

let apply middleware handler = middleware.filter handler

let apply_stack middleware_stack route =
  (* The request goes through the middlewares from top to bottom, so we have to reverse
     the middleware_stack *)
  let middleware_stack = List.rev middleware_stack in
  List.fold_left
    (fun route middleware ->
      let handler = Http.Route.handler route in
      let updated_handler = apply middleware handler in
      Http.Route.set_handler updated_handler route)
    route
    middleware_stack
;;
