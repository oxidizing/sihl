type t =
  { id : string
  ; filename : string
  ; filesize : int
  ; mime : string
  }
[@@deriving fields, yojson, show, eq, make]

let set_mime mime file = { file with mime }
let set_filesize filesize file = { file with filesize }
let set_filename filename file = { file with filename }
