module Repo = Sihl.Data.Repo.Service.Default
module Schedule = Sihl.Schedule.Service.Default

module Queue =
  Sihl.Queue.Service.MakePolling (Schedule) (Sihl.Queue.Service.Repo.MakeMemory (Repo))
