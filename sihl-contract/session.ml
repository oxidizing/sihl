open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val create : (string * string) list -> Session.t Lwt.t
  val set : Session.t -> key:string -> value:string -> unit Lwt.t
  val unset : Session.t -> key:string -> unit Lwt.t
  val get : Session.t -> key:string -> string option Lwt.t
  val find_opt : key:string -> Session.t option Lwt.t
  val find : key:string -> Session.t Lwt.t
  val find_all : unit -> Session.t list Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
