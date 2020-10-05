module Repository = Sihl.Repository.Service.Default
module Schedule = Sihl.Schedule.Service.Default
module Queue = Sihl_queue.MakePolling (Schedule) (Sihl_queue.Repo.MakeMemory (Repository))
