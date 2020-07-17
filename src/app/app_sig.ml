module type APP = sig
  val config : Config.t

  val services : Core_container.binding list

  val routes : Web.Server.stacked_routes

  val commands : Cmd.t list

  val schedules : Schedule.t list

  val on_start : Core_ctx.t -> (unit, string) Result.t Lwt.t

  val on_stop : Core_ctx.t -> (unit, string) Result.t Lwt.t
end
