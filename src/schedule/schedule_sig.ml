module type SERVICE = sig
  include Core_container.SERVICE

  val schedule : Core.Ctx.t -> Schedule_core.t -> Schedule_core.stop_schedule
  (** Run a schedule.

      Call the returned function to cancel a schedule. *)
end
