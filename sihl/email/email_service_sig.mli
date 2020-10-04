module type TEMPLATE_SERVICE = sig
  include Core.Container.Service.Sig

  val get : Core.Ctx.t -> id:string -> Email_core.Template.t option Lwt.t
  val get_by_name : Core.Ctx.t -> name:string -> Email_core.Template.t option Lwt.t

  val create
    :  Core.Ctx.t
    -> name:string
    -> html:string
    -> text:string
    -> Email_core.Template.t Lwt.t

  val update : Core.Ctx.t -> template:Email_core.Template.t -> Email_core.Template.t Lwt.t
  val render : Core.Ctx.t -> Email_core.t -> Email_core.t Lwt.t
  val configure : Core.Configuration.data -> Core.Container.Service.t
end

module type TEMPLATE_REPO = sig
  include Data.Repo.Service.Sig.REPO

  val get : Core.Ctx.t -> id:string -> Email_core.Template.t option Lwt.t
  val get_by_name : Core.Ctx.t -> name:string -> Email_core.Template.t option Lwt.t
  val insert : Core.Ctx.t -> template:Email_core.Template.t -> unit Lwt.t
  val update : Core.Ctx.t -> template:Email_core.Template.t -> unit Lwt.t
end

module type CONFIG_PROVIDER_SENDGRID = sig
  val api_key : Core.Ctx.t -> string Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** A template service to manage email templates. *)
  module Template : TEMPLATE_SERVICE

  (** Send email. *)
  val send : Core.Ctx.t -> Email_core.t -> unit Lwt.t

  (** Send multiple emails. If sending of one of them fails, the function fails.*)
  val bulk_send : Core.Ctx.t -> Email_core.t list -> unit Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
