module Context : sig
  type t

  val flash : t -> Middleware.Flash.Message.t option

  val csrf : t -> string
end

module Document : sig
  type t = Tyxml_html.doc
end

val render : Document.t -> string

val context : flash:Middleware.Flash.Message.t option -> unit -> Context.t
