module Repository = Sihl_repository
module Core = Sihl_core

module type REPO = sig
  include Repository.Sig.REPO

  val find_all : unit -> Model.t list Lwt.t
  val find_opt : key:string -> Model.t option Lwt.t
  val insert : Model.t -> unit Lwt.t
  val update : Model.t -> unit Lwt.t
  val delete : key:string -> unit Lwt.t
end

(* TODO document API after reading up on best practices *)
module type SERVICE = sig
  include Core.Container.Service.Sig

  val create : (string * string) list -> Model.t Lwt.t
  val set : Model.t -> key:string -> value:string -> unit Lwt.t
  val unset : Model.t -> key:string -> unit Lwt.t
  val get : Model.t -> key:string -> string option Lwt.t
  val find_opt : key:string -> Model.t option Lwt.t
  val find : key:string -> Model.t Lwt.t
  val find_all : unit -> Model.t list Lwt.t
  val register : unit -> Core.Container.Service.t
end
