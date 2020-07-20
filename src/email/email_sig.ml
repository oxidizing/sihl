module Template = struct
  module type SERVICE = sig
    include Core_container.SERVICE

    val render :
      Core.Ctx.t -> Email_core.t -> (Email_core.t, string) Result.t Lwt.t

    val create :
      Core.Ctx.t ->
      html:string ->
      text:string ->
      (Email_core.Template.t, string) Result.t Lwt.t
  end

  module type REPO = sig
    include Data.Repo.Sig.REPO

    val get :
      id:string ->
      Data_db_core.connection ->
      (Email_core.Template.t option, string) Result.t Lwt.t
  end
end

module ConfigProvider = struct
  module type SMTP = sig
    val smtp_host : Core.Ctx.t -> (string, string) Lwt_result.t

    val smtp_port : Core.Ctx.t -> (int, string) Lwt_result.t

    val smtp_secure : Core.Ctx.t -> (bool, string) Lwt_result.t
  end

  module type SENDGRID = sig
    val api_key : Core.Ctx.t -> (string, string) Lwt_result.t
  end
end

module type SERVICE = sig
  include Core_container.SERVICE

  val send : Core.Ctx.t -> Email_core.t -> (unit, string) Result.t Lwt.t
end
