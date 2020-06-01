module Component = Admin_component

module Page : sig
  type t

  val path : t -> string

  val label : t -> string

  val create : path:string -> label:string -> t
end

module Context = Admin_context

type 'a admin_page = Context.t -> 'a -> Template.Document.t

val render : Template.Context.t -> 'a admin_page -> 'a -> string

val register_page : Page.t -> unit

val get_all : unit -> Page.t list
