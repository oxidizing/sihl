module Repo = Sihl.Data.Repo.Service.Make ()

module Log = Sihl.Log.Service.Make ()

module Config = Sihl.Config.Service.Make (Log)
module Schedule = Sihl.Schedule.Service.Make (Log)
module Queue =
  Sihl.Queue.Service.MakePolling (Log) (Schedule)
    (Sihl.Queue.Service.Repo.MakeMemory (Repo))
