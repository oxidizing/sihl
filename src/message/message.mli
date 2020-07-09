module Core = Message_core

type t = Message_core.Message.t

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

val rotate : Core_ctx.t -> (unit, string) Result.t Lwt.t

val set :
  Core_ctx.t ->
  ?error:string list ->
  ?warning:string list ->
  ?success:string list ->
  ?info:string list ->
  unit ->
  (unit, string) Result.t Lwt.t

val get : Core_ctx.t -> (t option, string) Result.t Lwt.t
