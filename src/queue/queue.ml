module Service = Queue_service
module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance
module WorkableJob = Queue_core.WorkableJob

let create_job = Queue_core.Job.create

let set_max_tries = Queue_core.Job.set_max_tries

let set_retry_delay = Queue_core.Job.set_retry_delay
