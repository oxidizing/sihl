(** Use this module to display flash messages to the user across the request-response
    lifecycle. This is typically used to provide feedback to the user after submitting
    HTML forms. *)

module Core = Sihl_core
module Service = Service
module Sig = Sig
module Entry = Model.Entry

type t = Model.Message.t

val sexp_of_t : t -> Sexplib0.Sexp.t
val equal : t -> t -> bool
val pp : Format.formatter -> t -> unit
val show : t -> string
val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
val empty : t
val set_success : string list -> t -> t
val set_warning : string list -> t -> t
val set_error : string list -> t -> t
val set_info : string list -> t -> t
val get_error : t -> string list
val get_warning : t -> string list
val get_success : t -> string list
val get_info : t -> string list
val get : Core.Ctx.t -> t option
val ctx_add : t -> Core.Ctx.t -> Core.Ctx.t
