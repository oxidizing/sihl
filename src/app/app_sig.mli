module type APP = sig
  type t

  val empty : t

  val with_config : Configuration.t -> t -> t

  val with_schedules : Schedule.t list -> t -> t

  val with_endpoints : Web.Server.endpoint list -> t -> t

  val with_services : (module Core.Container.SERVICE) list -> t -> t

  val with_commands : Cmd.t list -> t -> t

  val on_start : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val on_stop : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val run : t -> unit
end

module type KERNEL = sig
  module Random : Utils.Random.Service.Sig.SERVICE

  module Log : Log.Service.Sig.SERVICE

  module Config : Configuration.Service.Sig.SERVICE

  module Db : Data.Db.Service.Sig.SERVICE

  module Migration : Data.Migration.Service.Sig.SERVICE

  module WebServer : Web.Server.Service.Sig.SERVICE

  module Cmd : Cmd.Service.Sig.SERVICE

  module Schedule : Schedule.Service.Sig.SERVICE
end
