module Template = struct
  module type SERVICE = sig
    include Sig.SERVICE

    val render :
      Core.Ctx.t -> Email_model.t -> (Email_model.t, string) Result.t Lwt.t
  end

  module type REPO = sig
    include Sig.REPO

    val get :
      id:string ->
      Core.Db.connection ->
      (Email_model.Template.t option, string) Result.t Lwt.t
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
  include Sig.SERVICE

  val send : Core.Ctx.t -> Email_model.t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "email.service"
