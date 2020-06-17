type t =
  [ `BadRequest of string option
  | `NotFound of string option
  | `Authentication of string option
  | `Authorization of string option
  | `Internal of string option ]
[@@deriving show, eq]

let bad_request ?msg () = `BadRequest msg

let not_found ?msg () = `NotFound msg

let not_found_of_opt = function
  | Ok (Some a) -> Ok a
  | Ok None -> Error (`NotFound None)
  | Error msg -> Error msg

let authentication _ = `Authentication None

let authorization ?msg () = `Authorization msg

let internal _ = `Internal None

let testable = Alcotest.testable pp equal
