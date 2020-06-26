type error =
  [ `BadRequest of string list
  | `NotAuthenticated
  | `NoPermissions of string
  | `Internal ]
[@@deriving show, eq, yojson]

let bad_request msgs = `BadRequest msgs

let not_authenticated _ = `NotAuthenticated

let no_permissions msg = `NoPermissions msg

let internal _ = `Internal

let alco_error = Alcotest.testable pp_error equal_error
