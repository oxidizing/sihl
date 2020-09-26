module type APP = sig
  type t

  val empty : t

  val with_services : (module Core.Container.SERVICE) list -> t -> t

  val on_before_start : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val on_after_start : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val on_before_stop : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val on_after_stop : (Core.Ctx.t -> unit Lwt.t) -> t -> t

  val run : t -> unit
end
