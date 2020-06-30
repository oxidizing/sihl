module type SERVICE = sig
  include Sig.SERVICE

  val register_page :
    Core.Ctx.t -> Admin_model.Page.t -> (unit, string) Result.t Lwt.t

  val get_all_pages :
    Core.Ctx.t -> (Admin_model.Page.t list, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "admin.service"
