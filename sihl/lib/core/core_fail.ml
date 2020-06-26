type error =
  [ `BadRequest of string list
  | `NotAuthenticated
  | `NoPermissions
  | `Internal of string ]
[@@deriving show, eq, yojson]

let bad_request msgs = `BadRequest msgs

let not_authenticated = `NotAuthenticated

let no_permissions = `NoPermissions

let internal ?(msg = "An error occurred, our administrators have been notified")
    () =
  `Internal msg

let alco_error = Alcotest.testable pp_error equal_error
