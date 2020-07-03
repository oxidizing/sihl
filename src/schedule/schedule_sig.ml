module type SERVICE = sig
  include Sig.SERVICE

  val register_schedules :
    Core_ctx.t -> Core_cmd.t list -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "schedule"
