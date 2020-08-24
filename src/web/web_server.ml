module Sig = Web_server_sig
module Service = Web_server_service

type routes = Web_server_core.routes

type middleware_stack = Web_server_core.middleware_stack

type endpoint = Web_server_core.endpoint
