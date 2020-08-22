open Base

module type REPO = sig
  include Data.Repo.Sig.REPO

  val get_all : Core.Ctx.t -> Session_core.t list Lwt.t

  val get : Core.Ctx.t -> key:string -> Session_core.t option Lwt.t

  val insert : Core.Ctx.t -> Session_core.t -> unit Lwt.t

  val update : Core.Ctx.t -> Session_core.t -> unit Lwt.t

  val delete : Core.Ctx.t -> key:string -> unit Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val set_value : Core.Ctx.t -> key:string -> value:string -> unit Lwt.t

  val remove_value : Core.Ctx.t -> key:string -> unit Lwt.t

  val get_value : Core.Ctx.t -> key:string -> string option Lwt.t

  val get_session : Core.Ctx.t -> key:string -> Session_core.t option Lwt.t

  val require_session_key : Core.Ctx.t -> string Lwt.t

  val get_all_sessions : Core.Ctx.t -> Session_core.t list Lwt.t

  val insert_session : Core.Ctx.t -> session:Session_core.t -> unit Lwt.t

  val create : Core_ctx.t -> (string * string) list -> Session_core.t Lwt.t
end

let middleware_key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("session.key", fun _ -> sexp_of_string "session.key")

let ctx_session_key : string Core.Ctx.key = Core.Ctx.create_key ()
