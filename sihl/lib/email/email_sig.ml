module Template = struct
  module type SERVICE = sig
    include Service.SERVICE

    val render :
      Opium.Std.Request.t ->
      Email_model.t ->
      (Email_model.t, string) Result.t Lwt.t
  end

  module type REPO = sig
    include Sig.REPO

    val get :
      id:string ->
      Core.Db.connection ->
      Email_model.Template.t Core.Db.db_result
  end
end

module ConfigProvider = struct
  module type SMTP = sig
    val smtp_host : Opium.Std.Request.t -> (string, string) Lwt_result.t

    val smtp_port : Opium.Std.Request.t -> (int, string) Lwt_result.t

    val smtp_secure : Opium.Std.Request.t -> (bool, string) Lwt_result.t
  end

  module type SENDGRID = sig
    val api_key : Opium.Std.Request.t -> (string, string) Lwt_result.t
  end
end

module type SERVICE = sig
  val send :
    Opium.Std.Request.t -> Email_model.t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.Key.t =
  Core.Container.Key.create "email.service"
