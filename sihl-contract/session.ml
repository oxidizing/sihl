open Sihl_type

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (* TODO [jerben] document API *)

  (* Session value *)
  val set_value : Session.t -> k:string -> v:string option -> unit Lwt.t
  val find_value : Session.t -> string -> string option Lwt.t

  (* Session *)
  val create : (string * string) list -> Session.t Lwt.t
  val find_opt : string -> Session.t option Lwt.t
  val find : string -> Session.t Lwt.t
  val find_all : unit -> Session.t list Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
