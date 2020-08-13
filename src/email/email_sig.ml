module Template = struct
  module type SERVICE = sig
    include Core_container.SERVICE

    val get :
      Core.Ctx.t ->
      id:string ->
      (Email_core.Template.t option, string) Result.t Lwt.t

    val get_by_name :
      Core.Ctx.t ->
      name:string ->
      (Email_core.Template.t option, string) Result.t Lwt.t

    val create :
      Core.Ctx.t ->
      name:string ->
      html:string ->
      text:string ->
      (Email_core.Template.t, string) Result.t Lwt.t

    val update :
      Core.Ctx.t ->
      template:Email_core.Template.t ->
      (Email_core.Template.t, string) Result.t Lwt.t

    val render :
      Core.Ctx.t -> Email_core.t -> (Email_core.t, string) Result.t Lwt.t
  end

  module type REPO = sig
    include Data.Repo.Sig.REPO

    val get :
      Core.Ctx.t ->
      id:string ->
      (Email_core.Template.t option, string) Result.t Lwt.t

    val get_by_name :
      Core.Ctx.t ->
      name:string ->
      (Email_core.Template.t option, string) Result.t Lwt.t

    val insert :
      Core.Ctx.t ->
      template:Email_core.Template.t ->
      (unit, string) Result.t Lwt.t

    val update :
      Core.Ctx.t ->
      template:Email_core.Template.t ->
      (unit, string) Result.t Lwt.t
  end
end

module ConfigProvider = struct
  (** Read the configurations from environment variables and set sane defaults.
[SMTP_SENDER]: Sender address from where the emails come from
[SMTP_HOST]: Host address of the SMTP server
[SMTP_USERNAME]: Username for the SMTP server login
[SMTP_USERNAME]: Password for the SMTP server login
[SMTP_PORT]: Port number, default is 587
[SMTP_START_TLS]: Whether to use TLS, default is true
[CA_DIR]: Location of root CA certificates on the file system, default is /etc/ssl/certs
*)
  module type SMTP = sig
    val sender : Core.Ctx.t -> (string, string) Lwt_result.t

    val username : Core.Ctx.t -> (string, string) Lwt_result.t

    val password : Core.Ctx.t -> (string, string) Lwt_result.t

    val host : Core.Ctx.t -> (string, string) Lwt_result.t

    val port : Core.Ctx.t -> (int option, string) Lwt_result.t

    val start_tls : Core.Ctx.t -> (bool, string) Lwt_result.t

    val ca_dir : Core.Ctx.t -> (string, string) Lwt_result.t
  end

  module type SENDGRID = sig
    val api_key : Core.Ctx.t -> (string, string) Lwt_result.t
  end
end

module type SERVICE = sig
  include Core_container.SERVICE

  module Template : Template.SERVICE

  val send : Core.Ctx.t -> Email_core.t -> unit Lwt.t

  val bulk_send : Core.Ctx.t -> Email_core.t list -> unit Lwt.t
end
