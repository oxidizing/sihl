module TemplateData : sig
  type t

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val empty : t

  val add : key:string -> value:string -> t -> t

  val make : (string * string) list -> t
end

module Template : sig
  type t

  val make : ?text:string -> ?html:string -> string -> t

  val created_at : t -> Ptime.t

  val status : t -> string

  val content_html : t -> string

  val content_text : t -> string

  val label : t -> string

  val id : t -> string

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val t : t Caqti_type.t

  val render : TemplateData.t -> t -> string
end

type t = Email_model.t

val make :
  sender:string ->
  recipient:string ->
  subject:string ->
  content:string ->
  ?cc:string list ->
  ?bcc:string list ->
  html:bool ->
  ?template_id:string ->
  ?template_data:TemplateData.t ->
  unit ->
  t

val template_data : t -> TemplateData.t

val template_id : t -> string option

val html : t -> bool

val bcc : t -> string list

val cc : t -> string list

val content : t -> string

val subject : t -> string

val recipient : t -> string

val sender : t -> string

val set_content : string -> t -> t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

module Service : sig
  module Template = Email_sig.Template
  module ConfigProvider = Email_sig.ConfigProvider

  module type SERVICE = Email_sig.SERVICE

  val key : (module SERVICE) Core_container.key
end

val send : Http.Req.t -> t -> (unit, string) Result.t Lwt.t
