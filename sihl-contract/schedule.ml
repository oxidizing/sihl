open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Run a schedule.

      Call the returned function to cancel a schedule. *)
  val schedule : Schedule.t -> Schedule.stop_schedule

  val register : ?schedules:Schedule.t list -> unit -> Sihl_core.Container.Service.t
end
