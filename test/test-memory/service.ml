module Repo = Sihl.Data.Repo.Service
module Log = Sihl.Log.Service
module Config = Sihl.Config.Service
module Schedule = Sihl.Schedule.Service.Make (Log)
module Queue =
  Sihl.Queue.Service.MakePolling (Log) (Schedule)
    (Sihl.Queue.Service.Repo.MakeMemory (Repo))
