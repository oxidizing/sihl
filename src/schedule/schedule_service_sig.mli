module type SERVICE = sig
  include Core.Container.Service.Sig

  val schedule : Core.Ctx.t -> Schedule_core.t -> Schedule_core.stop_schedule
  (** Run a schedule.

      Call the returned function to cancel a schedule. *)

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
