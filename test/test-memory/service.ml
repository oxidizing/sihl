module Db = struct
  let on_init _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let create_pool _ = failwith "Testing"

  let ctx_with_pool () = Sihl.Core.Ctx.empty

  let add_pool ctx = ctx

  let query_connection _ _ = failwith "Testing"

  let query ctx f =
    match Sihl.Core.Ctx.find Sihl.Data.Db.ctx_key_connection ctx with
    | Some connection -> f connection
    | None -> failwith "Failed to find connection"

  let atomic _ ?no_rollback:_ _ = failwith "Testing"

  let set_fk_check _ ~check:_ = failwith "Testing"
end

module Repo = struct
  let on_init _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_cleaner _ _ = Lwt_result.return ()

  let register_cleaners _ _ = Lwt_result.return ()

  let clean_all _ = Lwt_result.return ()
end

module Log = Sihl.Log.Service
module Config = Sihl.Config.Service
module Migration =
  Sihl.Data.Migration.Service.Make
    (Db)
    (Sihl.Data.Migration.Service.Repo.MariaDb)
module Test = Sihl.Test.Make (Migration) (Config)
module Schedule = Sihl.Schedule.Service.Make (Log)
module Queue =
  Sihl.Queue.Service.MakePolling (Log) (Db) (Repo) (Migration) (Schedule)
    (Sihl.Queue.Service.Repo.Memory)
