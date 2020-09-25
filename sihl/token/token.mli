(** The token service provides an API to generate tokens that carry some data and expire after a certain amount of time. It takes care of secure random byte generation and the persistence and validation of tokens.

*)

module Service = Token_service

exception Exception of Base.string

module Status : sig
  type t = Active | Inactive

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val to_string : t -> string

  val of_string : string -> (t, string) result
end

type t = Token_core.t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val created_at : t -> Ptime.t

val expires_at : t -> Ptime.t

val status : t -> Status.t

val kind : t -> string

val data : t -> string option

val value : t -> string

val id : t -> string

val make :
  id:string ->
  value:string ->
  data:string option ->
  kind:string ->
  status:Status.t ->
  expires_at:Ptime.t ->
  created_at:Ptime.t ->
  t

val alco : t Alcotest.testable

val t : t Caqti_type.t
