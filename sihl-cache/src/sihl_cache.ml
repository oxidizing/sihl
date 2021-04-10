let log_src = Logs.Src.create ("sihl.service." ^ Sihl.Contract.Cache.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

module MakeSql (Repo : Repo_sql.Sig) : Sihl.Contract.Cache.Sig = struct
  let find = Repo.find

  let set (k, v) =
    match v with
    | Some v ->
      (match%lwt find k with
      | Some _ -> Repo.update (k, v)
      | None -> Repo.insert (k, v))
    | None ->
      (match%lwt find k with
      | Some _ -> Repo.delete k
      | None ->
        (* nothing to do *)
        Lwt.return ())
  ;;

  (* Lifecycle *)

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Cache.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl.Container.Service.create lifecycle
  ;;
end

module PostgreSql =
  MakeSql (Repo_sql.MakePostgreSql (Sihl.Database.Migration.PostgreSql))

module MariaDb = MakeSql (Repo_sql.MakeMariaDb (Sihl.Database.Migration.MariaDb))
