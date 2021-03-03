type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }

type steps = step list
type t = string * steps

let name = "migration"

exception Exception of string
exception Dirty_migration

module type Sig = sig
  (** [register_migration migration] registers a migration [migration] with the
      migration service so it can be executed with `run_all`. *)
  val register_migration : t -> unit

  (** [register_migrations migrations] registers migrations [migrations] with
      the migration service so it can be executed with `run_all`. *)
  val register_migrations : t list -> unit

  (** [execute migrations] runs all migrations [migrations]. *)
  val execute : t list -> unit Lwt.t

  (** [run_all ()] runs all migrations that have been registered. *)
  val run_all : unit -> unit Lwt.t

  (** [pending_migrations ()] returns a list of migrations that need to be
      executed in order to have all migrations applied. The returned migration
      is a tuple [(namespace, number)] where [namespace] is the namespace of the
      migration and [number] is the number of pending migrations that need to be
      applied in order to achieve the desired schema version.

      An empty list means that there are no pending migrations and that the
      database schema is up-to-date. *)
  val pending_migrations : unit -> (string * int) list Lwt.t

  val register : ?migrations:t list -> unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common *)
let to_sexp (namespace, steps) =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  let steps =
    List.map
      (fun { label; statement; check_fk } ->
        List
          [ List [ Atom "label"; sexp_of_string label ]
          ; List [ Atom "statement"; sexp_of_string statement ]
          ; List [ Atom "check_fk"; sexp_of_bool check_fk ]
          ])
      steps
  in
  List (List.cons (List [ Atom "namespace"; sexp_of_string namespace ]) steps)
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)
let empty namespace = namespace, []

let create_step ~label ?(check_fk = true) statement =
  { label; check_fk; statement }
;;

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = label, List.concat [ steps; [ step ] ]
