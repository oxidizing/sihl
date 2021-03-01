let name = "schedule"

module type Sig = sig
  (** [schedule t] runs a schedule [t].

      Call the returned function to cancel a schedule. *)
  val schedule : Core_schedule.t -> Core_schedule.stop_schedule

  val register
    :  ?schedules:Core_schedule.t list
    -> unit
    -> Core_container.Service.t

  include Core_container.Service.Sig
end
