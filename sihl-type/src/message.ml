open Sexplib.Std

type t =
  { error : string list
  ; warning : string list
  ; success : string list
  ; info : string list
  }
[@@deriving eq, show, yojson, sexp]

let empty = { error = []; warning = []; success = []; info = [] }
let set_success txts message = { message with success = txts }
let set_warning txts message = { message with warning = txts }
let set_error txts message = { message with error = txts }
let set_info txts message = { message with info = txts }
let get_error message = message.error
let get_warning message = message.warning
let get_success message = message.success
let get_info message = message.info
