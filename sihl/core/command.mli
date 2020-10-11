(** A module to register and run CLI commands.

    A CLI command is the entry t a Sihl app. Services contribute their own set of
    commands, making every Sihl app and the available commands per Sihl app dynamic and
    dependent on the set of active services. *)

(** A function that takes a list of strings as argument and does some side effect. *)
type fn = string list -> unit Lwt.t

(** A CLI command has a unique name, an optional help text that shows the usage, a
    description that gives background information and the actual CLI function. *)
type t =
  { name : string
  ; help : string option
  ; description : string
  ; fn : fn
  }

exception Exception of string

val make : name:string -> ?help:string -> description:string -> fn -> t

(** {1 Running commands} *)

(** Call [run commands args] in the main Sihl app executable to pass command line
    arguments to all registered [commands]. This is the main entry point to a Sihl app. An
    optional list of arguments [args] can be passed, if [None] is passed, it reads the
    arguments from [Sys.argv]. *)
val run : t list -> string list option -> unit Lwt.t

(** {1 Utilities} *)

(** [sexp_of_t t] converts the command [t] to an s-expression *)
val sexp_of_t : t -> Sexplib0.Sexp.t

(** [pp] formats the command [t] as an s-expression *)
val pp : Format.formatter -> t -> unit
  [@@ocaml.toplevel_printer]
