module Component = Admin_component
module Page = Admin_page
module Context = Admin_context
module Bind = Admin_bind

type 'a admin_page = Context.t -> 'a -> Template.Document.t

val render : Template.Context.t -> 'a admin_page -> 'a -> string

val register_page : Page.t -> unit

val get_all : unit -> Page.t list
