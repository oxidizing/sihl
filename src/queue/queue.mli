module Service = Queue_service
module Sig = Queue_sig
module Core = Queue_core

val create_job :
  name:string ->
  ?with_context:(Sihl__Core.Ctx.t -> Sihl__Core.Ctx.t) ->
  input_to_string:('a -> string option) ->
  string_to_input:(string option -> ('a, string) Result.t) ->
  handle:(Sihl__Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t) ->
  ?failed:(Sihl__Core.Ctx.t -> (unit, string) Result.t Lwt.t) ->
  unit ->
  'a Core.Job.t

val set_max_tries : int -> 'a Core.Job.t -> 'a Core.Job.t

val set_retry_delay : Utils_time.duration -> 'a Core.Job.t -> 'a Core.Job.t
