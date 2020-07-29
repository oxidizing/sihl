module type SERVICE = sig
  include Core_container.SERVICE

  val register_commands :
    Core_ctx.t -> Cmd_core.t list -> (unit, string) Result.t Lwt.t

  val register_command :
    Core_ctx.t -> Cmd_core.t -> (unit, string) Result.t Lwt.t

  val run : unit -> unit Lwt.t
end
