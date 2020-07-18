module type SERVICE = sig
  include Core_container.SERVICE

  val register_commands :
    Core_ctx.t -> Cmd_core.t list -> (unit, string) Result.t Lwt.t

  val run : Core_ctx.t -> (unit, string) Result.t Lwt.t
end
