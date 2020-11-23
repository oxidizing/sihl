module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Run a schedule.

      Call the returned function to cancel a schedule. *)
  val schedule : Sihl_core.Schedule.t -> Sihl_core.Schedule.stop_schedule

  val register
    :  ?schedules:Sihl_core.Schedule.t list
    -> unit
    -> Sihl_core.Container.Service.t
end
