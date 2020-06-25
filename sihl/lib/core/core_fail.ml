type error =
  [ `BadRequest of string | `NotAuthenticated | `NoPermissions | `Internal ]
[@@deriving show, eq, yojson]

let bad_request msg = `BadRequest msg

let not_authenticated = `NotAuthenticated

let no_permissions = `NoPermissions

let internal = `Internal

let alco_error = Alcotest.testable pp_error equal_error
