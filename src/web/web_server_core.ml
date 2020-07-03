type routes = Web_route.t list

type middleware_stack = Web_middleware.t list

type stacked_routes = (string * routes * middleware_stack) list
