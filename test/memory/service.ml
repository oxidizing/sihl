module Repository = Sihl.Service.Repository
module Schedule = Sihl.Service.Schedule
module Queue = Sihl_queue.MakePolling (Schedule) (Sihl_queue.Repo.Memory)
