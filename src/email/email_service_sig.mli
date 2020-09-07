module type TEMPLATE_SERVICE = sig
  include Core.Container.SERVICE

  val get : Core.Ctx.t -> id:string -> Email_core.Template.t option Lwt.t

  val get_by_name :
    Core.Ctx.t -> name:string -> Email_core.Template.t option Lwt.t

  val create :
    Core.Ctx.t ->
    name:string ->
    html:string ->
    text:string ->
    Email_core.Template.t Lwt.t

  val update :
    Core.Ctx.t -> template:Email_core.Template.t -> Email_core.Template.t Lwt.t

  val render : Core.Ctx.t -> Email_core.t -> Email_core.t Lwt.t
end

module type TEMPLATE_REPO = sig
  include Data.Repo.Service.Sig.REPO

  val get : Core.Ctx.t -> id:string -> Email_core.Template.t option Lwt.t

  val get_by_name :
    Core.Ctx.t -> name:string -> Email_core.Template.t option Lwt.t

  val insert : Core.Ctx.t -> template:Email_core.Template.t -> unit Lwt.t

  val update : Core.Ctx.t -> template:Email_core.Template.t -> unit Lwt.t
end

module type CONFIG_PROVIDER_SMTP = sig
  (** Read the configurations from environment variables and set sane defaults.

      [SMTP_SENDER]: Sender address from where the emails come from

      [SMTP_HOST]: Host address of the SMTP server

      [SMTP_USERNAME]: Username for the SMTP server login

      [SMTP_PASSWORD]: Password for the SMTP server login

      [SMTP_PORT]: Port number, default is 587

      [SMTP_START_TLS]: Whether to use TLS, default is true

      [SMTP_CA_PATH]: Location of root CA certificates on the file system

      [SMTP_CA_CERT]: Location of CA certificates bundle on the file system

      Either one of [SMTP_CA_PATH] or [SMTP_CA_CERT] should be passed or neither
      of them that triggers use of auto detection. If both are provided,
      [SMTP_CA_PATH] will be ignored.
 *)

  val sender : Core.Ctx.t -> string Lwt.t

  val username : Core.Ctx.t -> string Lwt.t

  val password : Core.Ctx.t -> string Lwt.t

  val host : Core.Ctx.t -> string Lwt.t

  val port : Core.Ctx.t -> int option Lwt.t

  val start_tls : Core.Ctx.t -> bool Lwt.t

  val ca_path : Core.Ctx.t -> string option Lwt.t

  val ca_cert : Core.Ctx.t -> string option Lwt.t
end

module type CONFIG_PROVIDER_SENDGRID = sig
  val api_key : Core.Ctx.t -> string Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  module Template : TEMPLATE_SERVICE
  (** A template service to manage email templates. *)

  val send : Core.Ctx.t -> Email_core.t -> unit Lwt.t
  (** Send email. *)

  val bulk_send : Core.Ctx.t -> Email_core.t list -> unit Lwt.t
  (** Send multiple emails. If sending of one of them fails, the function fails.*)
end
