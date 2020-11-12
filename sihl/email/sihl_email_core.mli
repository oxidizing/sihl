(** Use this module to send single emails either immediately or later sending a lot of
    emails at once. Email template support is also provided. *)

exception Exception of string

module Template : sig
  module Data : sig
    type t = Model.Template.Data.t

    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val equal : t -> t -> bool
    val empty : t
    val add : key:string -> value:string -> t -> t
    val make : (string * string) list -> t
  end

  type t = Model.Template.t

  val make : ?text:string -> ?html:string -> string -> t
  val created_at : t -> Ptime.t
  val content_html : t -> string
  val content_text : t -> string
  val name : t -> string
  val id : t -> string
  val set_name : string -> t -> t
  val set_text : string -> t -> t
  val set_html : string -> t -> t
  val pp : Format.formatter -> t -> unit
  val show : t -> string
  val equal : t -> t -> bool
  val t : t Caqti_type.t
  val render : Data.t -> t -> string * string
end

type t = Model.t

val get_inbox : unit -> t list
val add_to_inbox : t -> unit
val clear_inbox : unit -> unit

val make
  :  sender:string
  -> recipient:string
  -> subject:string
  -> text_content:string
  -> html_content:string
  -> ?cc:string list
  -> ?bcc:string list
  -> html:bool
  -> ?template_id:string
  -> ?template_data:Template.Data.t
  -> unit
  -> t

val template_data : t -> Template.Data.t
val template_id : t -> string option
val html : t -> bool
val bcc : t -> string list
val cc : t -> string list
val text_content : t -> string
val html_content : t -> string
val subject : t -> string
val recipient : t -> string
val sender : t -> string
val set_text_content : string -> t -> t
val set_html_content : string -> t -> t
val pp : Format.formatter -> t -> unit
val show : t -> string
val equal : t -> t -> bool
val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

module Sig = Sig
