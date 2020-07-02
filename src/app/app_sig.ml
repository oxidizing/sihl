module type APP = sig
  val config : Core_config.Setting.t

  val services : Core_container.binding list

  val routes : Web.Server.stacked_routes

  val commands : Core_cmd.t list

  val schedules : Schedule.t list

  val admin_pages : Admin.Page.t list

  val on_start : Core_ctx.t -> (unit, string) Result.t Lwt.t

  val on_stop : Core_ctx.t -> (unit, string) Result.t Lwt.t
end
