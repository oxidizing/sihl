module Map = Map.Make (String)

type data = string Map.t

type t =
  { key : string
  ; expire_date : Ptime.t
  }

let sexp_of_t { key; expire_date; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "key"; sexp_of_string key ]
    ; List [ Atom "expire_date"; sexp_of_string (Ptime.to_rfc3339 expire_date) ]
    ]
;;

let expiration_date now = Sihl_core.Time.date_from_now now Sihl_core.Time.OneWeek
let key session = session.key
let is_expired now session = Ptime.is_later now ~than:session.expire_date

(* Signature *)
let name = "sihl.service.session"

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
