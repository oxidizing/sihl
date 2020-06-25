type error

val pp_error : Format.formatter -> error -> unit

val show_error : error -> string

val equal_error : error -> error -> bool

val error_to_yojson : error -> Yojson.Safe.t

val error_of_yojson :
  Yojson.Safe.t -> error Ppx_deriving_yojson_runtime.error_or

val bad_request : string -> [> `BadRequest of string ]

val not_authenticated : [> `NotAuthenticated ]

val no_permissions : [> `NoPermissions ]

val internal : [> `Internal ]
