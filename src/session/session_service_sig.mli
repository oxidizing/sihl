open Base

module type REPO = sig
  include Data.Repo.Service.Sig.REPO

  val find_all : Core.Ctx.t -> Session_core.t list Lwt.t

  val find_opt : Core.Ctx.t -> key:string -> Session_core.t option Lwt.t

  val insert : Core.Ctx.t -> Session_core.t -> unit Lwt.t

  val update : Core.Ctx.t -> Session_core.t -> unit Lwt.t

  val delete : Core.Ctx.t -> key:string -> unit Lwt.t
end

(* TODO document API after reading up on best practices *)
module type SERVICE = sig
  include Core.Container.SERVICE

  val add_to_ctx : Session_core.t -> Core.Ctx.t -> Core.Ctx.t

  val create : Core.Ctx.t -> (string * string) list -> Session_core.t Lwt.t

  val set : Core.Ctx.t -> key:string -> value:string -> unit Lwt.t

  val unset : Core.Ctx.t -> key:string -> unit Lwt.t

  val get : Core.Ctx.t -> key:string -> string option Lwt.t

  val find_opt : Core.Ctx.t -> key:string -> Session_core.t option Lwt.t

  val find : Core.Ctx.t -> key:string -> Session_core.t Lwt.t

  val find_all : Core.Ctx.t -> Session_core.t list Lwt.t
end
