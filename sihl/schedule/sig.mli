module Core = Sihl_core

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Run a schedule.

      Call the returned function to cancel a schedule. *)
  val schedule : Core.Ctx.t -> Model.t -> Model.stop_schedule

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
