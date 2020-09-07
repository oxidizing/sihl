(** This module implements JSON Web tokens. They are typically used decouple authentication from the other parts of a system. *)

type algorithm = Jwto.algorithm = HS256 | HS512 | Unknown

type t = Jwto.t

type payload

val empty : payload

val add_claim : key:string -> value:string -> payload -> payload

val set_expires_in : now:Ptime.t -> Utils_time.duration -> payload -> payload
(** Adds the "exp" claim. *)

val encode : algorithm -> secret:string -> payload -> (string, string) result

val decode : secret:string -> string -> (t, string) result
(** Checks whether the signature is correct and decodes the base64 string representation to [t]. *)

val get_claim : key:string -> t -> string option

val is_expired : now:Ptime.t -> ?claim:string -> t -> bool
(** Checks whether the [claim] of the token [t] is in the past by looking at [now]. If no exp claim was not found the token can not expire and [is_expired] returns true. A custom [claim] can be provided, by default it looks for "exp".*)

val pp : Format.formatter -> t -> unit

val eq : t -> t -> bool

module Jwto = Jwto
