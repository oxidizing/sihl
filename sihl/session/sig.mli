module Repository = Sihl_repository
module Core = Sihl_core

module type REPO = sig
  include Repository.Sig.REPO

  val find_all : Core.Ctx.t -> Model.t list Lwt.t
  val find_opt : Core.Ctx.t -> key:string -> Model.t option Lwt.t
  val insert : Core.Ctx.t -> Model.t -> unit Lwt.t
  val update : Core.Ctx.t -> Model.t -> unit Lwt.t
  val delete : Core.Ctx.t -> key:string -> unit Lwt.t
end

(* TODO document API after reading up on best practices *)
module type SERVICE = sig
  include Core.Container.Service.Sig

  val create : Core.Ctx.t -> (string * string) list -> Model.t Lwt.t
  val set : Core.Ctx.t -> Model.t -> key:string -> value:string -> unit Lwt.t
  val unset : Core.Ctx.t -> Model.t -> key:string -> unit Lwt.t
  val get : Core.Ctx.t -> Model.t -> key:string -> string option Lwt.t
  val find_opt : Core.Ctx.t -> key:string -> Model.t option Lwt.t
  val find : Core.Ctx.t -> key:string -> Model.t Lwt.t
  val find_all : Core.Ctx.t -> Model.t list Lwt.t
  val configure : Core.Configuration.data -> Core.Container.Service.t
end
