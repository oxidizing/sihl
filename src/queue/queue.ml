module Service = Queue_service
module Sig = Queue_sig
module Core = Queue_core

let create_job = Queue_core.Job.create

let set_max_tries = Queue_core.Job.set_max_tries

let set_retry_delay = Queue_core.Job.set_retry_delay
