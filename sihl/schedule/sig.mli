module Core = Sihl_core

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Run a schedule.

      Call the returned function to cancel a schedule. *)
  val schedule : Model.t -> Model.stop_schedule

  val register : ?schedules:Model.t list -> unit -> Core.Container.Service.t
end
