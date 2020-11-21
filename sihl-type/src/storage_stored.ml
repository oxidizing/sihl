type t =
  { file : Storage_file.t
  ; blob : string
  }
[@@deriving fields, yojson, show, eq, make]

let mime stored_file = Storage_file.mime stored_file.file
let filesize stored_file = Storage_file.filesize stored_file.file
let filename stored_file = Storage_file.filename stored_file.file

let set_mime mime stored_file =
  { stored_file with file = Storage_file.set_mime mime stored_file.file }
;;

let set_filesize size stored_file =
  { stored_file with file = Storage_file.set_filesize size stored_file.file }
;;

let set_filename name stored_file =
  { stored_file with file = Storage_file.set_filename name stored_file.file }
;;
