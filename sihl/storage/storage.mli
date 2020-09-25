(** Use this module to store and retrieve large files. This is typically used for binary files such as images or audio.

*)

exception Exception of string

module File = Storage_core.File
module StoredFile = Storage_core.StoredFile
module Sig = Sig
