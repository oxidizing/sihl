module Repository = Sihl_repository
module Core = Sihl_core

module type TEMPLATE_SERVICE = sig
  include Core.Container.Service.Sig

  val get : id:string -> Model.Template.t option Lwt.t
  val get_by_name : name:string -> Model.Template.t option Lwt.t
  val create : name:string -> html:string -> text:string -> Model.Template.t Lwt.t
  val update : template:Model.Template.t -> Model.Template.t Lwt.t
  val render : Model.t -> Model.t Lwt.t
  val register : unit -> Core.Container.Service.t
end

module type TEMPLATE_REPO = sig
  include Repository.Sig.REPO

  val get : id:string -> Model.Template.t option Lwt.t
  val get_by_name : name:string -> Model.Template.t option Lwt.t
  val insert : template:Model.Template.t -> unit Lwt.t
  val update : template:Model.Template.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** A template service to manage email templates. *)
  module Template : TEMPLATE_SERVICE

  (** Send email. *)
  val send : Model.t -> unit Lwt.t

  (** Send multiple emails. If sending of one of them fails, the function fails.*)
  val bulk_send : Model.t list -> unit Lwt.t

  val register : unit -> Core.Container.Service.t
end
