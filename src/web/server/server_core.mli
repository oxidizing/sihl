type routes = Http.Route.t list

type middleware_stack = Middleware.stack

type endpoint = string * routes * middleware_stack
