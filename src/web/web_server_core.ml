open Base

type routes = Web_route.t list

type middleware_stack = Web_middleware.stack

type endpoint = string * routes * middleware_stack
