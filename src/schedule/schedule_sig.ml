module type SERVICE = sig
  include Core_container.SERVICE

  val register_schedules :
    Core_ctx.t -> Schedule_core.t list -> (unit, string) Result.t Lwt.t

  val schedule : Core.Ctx.t -> Schedule_core.t -> Schedule_core.stop_schedule
end
