type routes = Web_route.t list

type middleware_stack = Web_middleware.stack

type endpoint = string * routes * middleware_stack

val endpoints_to_opium_builders : endpoint list -> Opium.Std.App.builder list
