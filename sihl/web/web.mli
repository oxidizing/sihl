(** This module provides the HTTP stack including API for requests, responses,
    middlewares, templating and a web server service. *)

(** {1 HTTP} *)

exception Exception of string

type content_type = Http.Core.content_type =
  | Html
  | Json
  | Pdf

val pp_content_type
  :  Ppx_deriving_runtime.Format.formatter
  -> content_type
  -> Ppx_deriving_runtime.unit

val equal_content_type : content_type -> content_type -> Ppx_deriving_runtime.bool
val show_content_type : content_type -> string

type header = string * string

val pp_header
  :  Ppx_deriving_runtime.Format.formatter
  -> header
  -> Ppx_deriving_runtime.unit

val show_header : header -> Ppx_deriving_runtime.string
val equal_header : header -> header -> Ppx_deriving_runtime.bool

type headers = header list

val pp_headers
  :  Ppx_deriving_runtime.Format.formatter
  -> headers
  -> Ppx_deriving_runtime.unit

val show_headers : headers -> Ppx_deriving_runtime.string
val equal_headers : headers -> headers -> Ppx_deriving_runtime.bool

module Req = Http.Req
module Res = Http.Res
module Route = Http.Route
module Template = Http.Template
module Utils = Http.Utils

(** {1 Middleware} *)

module Middleware = Middleware

(** {1 Server} *)

module Server = Server
