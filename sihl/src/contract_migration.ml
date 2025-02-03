type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }
[@@deriving eq, show]

type steps = step list [@@deriving eq, show]
type t = string * steps [@@deriving eq, show]

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

  (** [execute ?ctx migrations] runs all migrations [migrations] on the
      connection pool. *)
  val execute : ?ctx:(string * string) list -> t list -> unit Lwt.t

  (** [run_all ?ctx ()] runs all migrations that have been registered on the
      connection pool. *)
  val run_all : ?ctx:(string * string) list -> unit -> unit Lwt.t

  (** [migrations_status ?ctx ?migrations ()] returns a list of migration
      namespaces and the number of their unapplied migrations.

      By default, the migrations are checked that have been registered when
      registering the migration service. Custom [migrations] can be provided to
      override this behaviour. *)
  val migrations_status
    :  ?ctx:(string * string) list
    -> ?migrations:t list
    -> unit
    -> (string * int option) list Lwt.t

  (** [check_migration_status ?ctx ?migrations ()] returns a list of migration
      namespaces and the number of their unapplied migrations.

      It does the same thing as {!migration_status} and additionally interprets
      whether there are too many, not enough or just the right number of
      migrations applied. If there are too many or not enough migrations
      applied, a descriptive warning message is logged. *)
  val check_migrations_status
    :  ?ctx:(string * string) list
    -> ?migrations:t list
    -> unit
    -> unit Lwt.t

  (** [pending_migrations ?ctx ()] returns a list of migrations that need to be
      executed in order to have all migrations applied on the connection pool.
      The returned migration is a tuple [(namespace, number)] where [namespace]
      is the namespace of the migration and [number] is the number of pending
      migrations that need to be applied in order to achieve the desired schema
      version.

      An empty list means that there are no pending migrations and that the
      database schema is up-to-date. *)
  val pending_migrations
    :  ?ctx:(string * string) list
    -> unit
    -> (string * int) list Lwt.t

  val register : t list -> Core_container.Service.t

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
