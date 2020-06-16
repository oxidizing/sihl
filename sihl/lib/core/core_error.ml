type t =
  [ `BadRequest of string
  | `NotFound of string
  | `Authentication of string
  | `Authorization of string
  | `Internal of string ]
[@@deriving show, eq]

let bad_request msg = `BadRequest msg

let not_found msg = `NotFound msg

let authentication msg = `Authentication msg

let authorization msg = `Authorization msg

let internal msg = `Internal msg
