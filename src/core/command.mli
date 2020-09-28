(** A module to register and run CLI commands.

A CLI command is the entry t a Sihl app. Services contribute their own set of commands, making every Sihl app and the available commands per Sihl app dynamic and dependent on the set of active services. *)

type fn = string list -> unit Lwt.t

type t = { name : string; help : string option; description : string; fn : fn }

exception Exception of string

val make :
  name:string ->
  ?help:string ->
  description:string ->
  (string list -> unit Lwt.t) ->
  t

(** {1 Registering & Running commands } *)

(** {3 Run commands } *)

val run : t list -> unit Lwt.t
(** Call [run] in the main Sihl app executable to passes command line arguments to all registered commands. This is the main entry point to a Sihl app. *)

(** {1 Utilities} *)

(** {3 [sexp_of_t]} *)

val sexp_of_t : t -> Sexplib0.Sexp.t
(** [sexp_of_t t] converts the command [t] to an s-expression *)

(** {3 [pp]} *)

val pp : Format.formatter -> t -> unit
  [@@ocaml.toplevel_printer]
(** [pp] formats the command [t] as an s-expression *)
