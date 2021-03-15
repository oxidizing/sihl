module Map = Map.Make (String)

module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val enqueue : Sihl.Contract.Queue.instance -> unit Lwt.t
  val enqueue_all : Sihl.Contract.Queue.instance list -> unit Lwt.t
  val find_workable : unit -> Sihl.Contract.Queue.instance list Lwt.t
  val find : string -> Sihl.Contract.Queue.instance option Lwt.t
  val query : unit -> Sihl.Contract.Queue.instance list Lwt.t
  val update : Sihl.Contract.Queue.instance -> unit Lwt.t
  val delete : Sihl.Contract.Queue.instance -> unit Lwt.t
end

module InMemory : Sig = Repo_inmemory
module MariaDb : Sig = Repo_sql.MakeMariaDb (Sihl.Database.Migration.MariaDb)

module PostgreSql : Sig =
  Repo_sql.MakePostgreSql (Sihl.Database.Migration.PostgreSql)
