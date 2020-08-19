module type SERVICE = sig
  include Core_container.SERVICE

  val register_commands :
    Core_ctx.t -> Cmd_core.t list -> (unit, string) Result.t Lwt.t
  (** Registered commands can be executed by running the main Sihl app executable. *)

  val register_command :
    Core_ctx.t -> Cmd_core.t -> (unit, string) Result.t Lwt.t
  (** Registered commands can be executed by running the main Sihl app executable. *)

  val run : unit -> unit Lwt.t
  (** Call [run] in the main Sihl app executable to passes command line arguments to all registered commands. This is the main entry point to a Sihl app. *)
end
