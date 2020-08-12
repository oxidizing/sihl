module Sig = App_sig

module Make : functor (Kernel : App_sig.KERNEL) -> sig
  type t

  val empty : t

  val with_config : Config.t -> t -> t

  val with_routes : Web.Server.stacked_routes -> t -> t

  val with_services : (module Core.Container.SERVICE) list -> t -> t

  val with_schedules : Schedule.t list -> t -> t

  val with_commands : Cmd.t list -> t -> t

  val on_start : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val on_stop : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val run : t -> unit
end
