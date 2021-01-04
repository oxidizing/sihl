type t =
  { id : string
  ; label : string
  ; text : string
  ; html : string option
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }

let name = "email.template"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val get : string -> t option Lwt.t
  val get_by_label : string -> t option Lwt.t
  val create : ?html:string -> label:string -> string -> t Lwt.t
  val update : t -> t Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
