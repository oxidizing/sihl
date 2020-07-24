module Db = struct
  let on_init _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let create_pool _ = failwith "Testing"

  let ctx_with_pool _ = failwith "Testing ctx_with_pool"

  let add_pool ctx = ctx

  let query_connection _ _ = failwith "Testing"

  let query _ _ = failwith "Testing"

  let atomic _ ?no_rollback:_ _ = failwith "Testing"

  let set_fk_check _ ~check:_ = failwith "Testing"
end

module Log = Sihl.Log.Service
module Config = Sihl.Config.Service
module Migration =
  Sihl.Data.Migration.Service.Make
    (Db)
    (Sihl.Data.Migration.Service.Repo.MariaDb)
module Test = Sihl.Test.Make (Migration) (Config)
module Repo = Sihl.Data.Repo.Service.Make (Db)
module Queue =
  Sihl.Queue.Service.Make (Log) (Db) (Repo) (Migration)
    (Sihl.Queue.Service.Repo.Memory)
