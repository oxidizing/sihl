let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.Cache.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

let session_key_nr_bytes = 20

module MakeSql (Repo : Repo_sql.Sig) : Sihl_contract.Cache.Sig = struct
  let find = Repo.find

  let set (k, v) =
    let open Lwt.Syntax in
    match v with
    | Some v ->
      let* old_v = find k in
      (match old_v with
      | Some _ -> Repo.update (k, v)
      | None -> Repo.insert (k, v))
    | None ->
      let* old_v = find k in
      (match old_v with
      | Some _ -> Repo.delete k
      | None ->
        (* nothing to do *)
        Lwt.return ())
  ;;

  (* Lifecycle *)

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.create_lifecycle
      Sihl_contract.Cache.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl_core.Container.Service.create lifecycle
  ;;
end

module MigrationPostgreSql =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.PostgreSql)

module MigrationMariaDb =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.MariaDb)

module PostgreSql = MakeSql (Repo_sql.MakePostgreSql (MigrationPostgreSql))
module MariaDb = MakeSql (Repo_sql.MakeMariaDb (MigrationMariaDb))
