module type SERVICE = sig
  include Core_container.SERVICE

  val register_schedules :
    Core_ctx.t -> Schedule_core.t list -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "schedule"
