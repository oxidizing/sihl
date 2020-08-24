exception Exception of string

module File = struct
  type t = { id : string; filename : string; filesize : int; mime : string }
  [@@deriving fields, yojson, show, eq, make]

  let set_mime mime file = { file with mime }

  let set_filesize filesize file = { file with filesize }

  let set_filename filename file = { file with filename }
end

module StoredFile = struct
  type t = { file : File.t; blob : string }
  [@@deriving fields, yojson, show, eq, make]

  let mime stored_file = File.mime stored_file.file

  let filesize stored_file = File.filesize stored_file.file

  let filename stored_file = File.filename stored_file.file

  let set_mime mime stored_file =
    { stored_file with file = File.set_mime mime stored_file.file }

  let set_filesize size stored_file =
    { stored_file with file = File.set_filesize size stored_file.file }

  let set_filename name stored_file =
    { stored_file with file = File.set_filename name stored_file.file }
end
