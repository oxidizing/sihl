(** Use this module to store and retrieve large files. This is typically used for binary
    files such as images or audio. *)

exception Exception of string

module File = Model.File
module StoredFile = Model.StoredFile
module Sig = Sig
