module type SERVICE = sig
  include Core_container.SERVICE

  val register_commands : Cmd_core.t list -> unit
  (** Registered commands can be executed by running the main Sihl app executable. *)

  val register_command : Cmd_core.t -> unit
  (** Registered commands can be executed by running the main Sihl app executable. *)

  val run : unit -> unit Lwt.t
  (** Call [run] in the main Sihl app executable to passes command line arguments to all registered commands. This is the main entry point to a Sihl app. *)
end
