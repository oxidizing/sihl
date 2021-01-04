module Map = Map.Make (String)

type data = string Map.t

type t =
  { key : string
  ; expire_date : Ptime.t
  }

(* Signature *)
let name = "session"

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (* TODO [jerben] document API *)

  (* Session value *)
  val set_value : t -> k:string -> v:string option -> unit Lwt.t
  val find_value : t -> string -> string option Lwt.t

  (* Session *)
  val create : (string * string) list -> t Lwt.t
  val find_opt : string -> t option Lwt.t
  val find : string -> t Lwt.t
  val find_all : unit -> t list Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
