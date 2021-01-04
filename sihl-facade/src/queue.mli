open Sihl_contract

val to_sexp : 'a Queue.t -> Sexplib0.Sexp.t
val pp : Format.formatter -> 'a Queue.t -> unit
val default_tries : int
val default_retry_delay : Sihl_core.Time.duration

val create
  :  name:string
  -> input_to_string:('a -> string option)
  -> string_to_input:(string option -> ('a, string) result)
  -> handle:('a -> (unit, string) result Lwt.t)
  -> ?failed:(string -> (unit, string) Lwt_result.t)
  -> unit
  -> 'a Queue.t

val set_max_tries : int -> 'a Queue.t -> 'a Queue.t
val set_retry_delay : Sihl_core.Time.duration -> 'a Queue.t -> 'a Queue.t

include Sihl_contract.Queue.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  ?jobs:'a Queue.t list
  -> (module Queue.Sig)
  -> Sihl_core.Container.Service.t
