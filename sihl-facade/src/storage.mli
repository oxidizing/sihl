val file_to_sexp : Sihl_contract.Storage.file -> Sexplib0.Sexp.t
val pp_file : Format.formatter -> Sihl_contract.Storage.file -> unit

val set_mime
  :  string
  -> Sihl_contract.Storage.file
  -> Sihl_contract.Storage.file

val set_filesize
  :  int
  -> Sihl_contract.Storage.file
  -> Sihl_contract.Storage.file

val set_filename
  :  string
  -> Sihl_contract.Storage.file
  -> Sihl_contract.Storage.file

val set_mime_stored
  :  string
  -> Sihl_contract.Storage.stored
  -> Sihl_contract.Storage.stored

val set_filesize_stored
  :  int
  -> Sihl_contract.Storage.stored
  -> Sihl_contract.Storage.stored

val set_filename_stored
  :  string
  -> Sihl_contract.Storage.stored
  -> Sihl_contract.Storage.stored

val stored_to_sexp : Sihl_contract.Storage.stored -> Sexplib0.Sexp.t
val pp_stored : Format.formatter -> Sihl_contract.Storage.stored -> unit

include Sihl_contract.Storage.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Storage.Sig)
  -> Sihl_core.Container.Service.t
