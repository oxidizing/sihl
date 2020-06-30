type error =
  [ `BadRequest of string list
  | `NotAuthenticated
  | `NoPermissions of string
  | `Internal ]

val pp_error : Format.formatter -> error -> unit

val show_error : error -> string

val equal_error : error -> error -> bool

val error_to_yojson : error -> Yojson.Safe.t

val error_of_yojson :
  Yojson.Safe.t -> error Ppx_deriving_yojson_runtime.error_or

val bad_request : string list -> [> `BadRequest of string list ]

val not_authenticated : 'a -> [> `NotAuthenticated ]

val no_permissions : string -> [> `NoPermissions of string ]

val internal : string -> [> `Internal ]

val alco_error : error Alcotest.testable
