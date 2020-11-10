module Repository = Sihl.Repository.Service
module Schedule = Sihl.Schedule.Service
module Queue = Sihl_queue.MakePolling (Schedule) (Sihl_queue.Repo.Memory)
