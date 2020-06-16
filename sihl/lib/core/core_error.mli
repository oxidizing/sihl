type t =
  [ `Authentication of string
  | `Authorization of string
  | `BadRequest of string
  | `Internal of string
  | `NotFound of string ]

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val bad_request : 'a -> [> `BadRequest of 'a ]

val not_found : 'a -> [> `NotFound of 'a ]

val authentication : 'a -> [> `Authentication of 'a ]

val authorization : 'a -> [> `Authorization of 'a ]

val internal : 'a -> [> `Internal of 'a ]
