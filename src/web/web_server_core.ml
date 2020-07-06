open Base

type routes = Web_route.t list

type middleware_stack = Web_middleware.stack

type stacked_routes = (string * routes * middleware_stack) list

let stacked_routes_to_opium_builders stacked_routes =
  stacked_routes
  |> List.map ~f:(fun (prefix, routes, middleware_stack) ->
         routes
         |> List.map ~f:(Web_route.prefix prefix)
         |> List.map ~f:(Web_middleware.apply_stack middleware_stack)
         |> List.map ~f:Web_route.to_opium_builder)
  |> List.concat
