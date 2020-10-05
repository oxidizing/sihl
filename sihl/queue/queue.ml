module Job = Model.Job
module JobInstance = Model.JobInstance
module WorkableJob = Model.WorkableJob
module Sig = Sig

let create_job = Model.Job.create
let set_max_tries = Model.Job.set_max_tries
let set_retry_delay = Model.Job.set_retry_delay
