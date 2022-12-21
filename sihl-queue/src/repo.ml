module Map = Map.Make (String)

module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit

  val enqueue
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Queue.instance
    -> unit Lwt.t

  val enqueue_all
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Queue.instance list
    -> unit Lwt.t

  val find_workable
    :  ?ctx:(string * string) list
    -> unit
    -> Sihl.Contract.Queue.instance list Lwt.t

  val find
    :  ?ctx:(string * string) list
    -> string
    -> Sihl.Contract.Queue.instance option Lwt.t

  val query
    :  ?ctx:(string * string) list
    -> unit
    -> Sihl.Contract.Queue.instance list Lwt.t

  val search
    :  ?ctx:(string * string) list
    -> [ `Desc | `Asc ]
    -> string option
    -> limit:int
    -> offset:int
    -> (Sihl.Contract.Queue.instance list * int) Lwt.t

  val update
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Queue.instance
    -> unit Lwt.t

  val delete
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Queue.instance
    -> unit Lwt.t
end

module InMemory : Sig = Repo_inmemory
module MariaDb : Sig = Repo_sql.MakeMariaDb (Sihl.Database.Migration.MariaDb)

module PostgreSql : Sig =
  Repo_sql.MakePostgreSql (Sihl.Database.Migration.PostgreSql)
