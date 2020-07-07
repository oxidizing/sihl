module Sig = Admin_sig
module Service = Admin_service
module Component = Admin_component
module Page = Admin_core.Page

val register_page : Core_ctx.t -> Page.t -> (unit, string) result Lwt.t

val register_pages : Core_ctx.t -> Page.t list -> (unit, string) Lwt_result.t

val get_all_pages : Core_ctx.t -> (Page.t list, string) result Lwt.t

val create_page : path:string -> label:string -> Page.t
