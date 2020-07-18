module type KERNEL = sig
  module Random : Utils.Random.Sig.SERVICE

  module Log : Log.Sig.SERVICE

  module Config : Config.Sig.SERVICE

  module Db : Data.Db.Sig.SERVICE

  module Migration : Data.Migration.Sig.SERVICE

  module WebServer : Web.Server.Sig.SERVICE

  module Cmd : Cmd.Sig.SERVICE

  module Schedule : Schedule.Sig.SERVICE
end

module type APP = sig
  val config : Config.t

  val services : (module Core.Container.SERVICE) list

  val routes : Web.Server.stacked_routes

  val commands : Cmd.t list

  val schedules : Schedule.t list

  val on_start : Core_ctx.t -> (unit, string) Result.t Lwt.t

  val on_stop : Core_ctx.t -> (unit, string) Result.t Lwt.t
end
