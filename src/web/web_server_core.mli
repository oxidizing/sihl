type routes = Web_route.t list

type middleware_stack = Web_middleware.stack

type stacked_routes = (string * routes * middleware_stack) list

val stacked_routes_to_opium_builders :
  stacked_routes -> Opium.Std.App.builder list
