open Base

type t = { name : string; filter : Web_route.handler -> Web_route.handler }
[@@deriving show]

let create ~name filter = { name; filter }

type stack = t list [@@deriving show]

let apply middleware handler = middleware.filter handler

let apply_stack middleware_stack route =
  (* The request goes through the middlewares from top to bottom,
     so we have to reverse the middleware_stack *)
  let middleware_stack = List.rev middleware_stack in
  List.fold_left middleware_stack ~init:route ~f:(fun route middleware ->
      let handler = Web_route.handler route in
      let updated_handler = apply middleware handler in
      Web_route.set_handler updated_handler route)
