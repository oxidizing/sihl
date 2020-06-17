type t =
  [ `Authentication of string option
  | `Authorization of string option
  | `BadRequest of string option
  | `Internal of string option
  | `NotFound of string option ]

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val bad_request : ?msg:string -> unit -> [> `BadRequest of string option ]

val not_found : ?msg:string -> unit -> [> `NotFound of string option ]

val not_found_of_opt : ('a option, t) Result.t -> ('a, t) Result.t

val authentication : 'a -> [> `Authentication of 'b option ]

val authorization : ?msg:string -> unit -> [> `Authorization of string option ]

val internal : 'a -> [> `Internal of 'b option ]

val testable : t Alcotest.testable
