open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Send email. *)
  val send : Email.t -> unit Lwt.t

  (** Send multiple emails. If sending of one of them fails, the function fails.*)
  val bulk_send : Email.t list -> unit Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
