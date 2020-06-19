module type ADMIN_SERVICE = sig
  val register_page : Admin_page.t -> unit

  val get_all_pages : unit -> Admin_page.t list
end

val registry_key : (module ADMIN_SERVICE) Core.Container.Key.t

module Service : sig
  val register_page : Admin_page.t -> unit

  val get_all_pages : unit -> Admin_page.t list
end
