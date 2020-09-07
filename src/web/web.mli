(** This module provides the HTTP stack including API for requests, responses, middlewares, templating and a web server service. *)

(** {1 HTTP} *)

module Req = Http.Req
module Res = Http.Res
module Route = Http.Route
module Template = Http.Template
module Utils = Http.Utils

(** {1 Middleware} *)

module Middleware = Middleware

(** {1 Server} *)

module Server = Server
