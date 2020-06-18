val request_with_connection : unit -> Opium.Std.Request.t Lwt.t

val seed : (Opium.Std.Request.t -> 'a Lwt.t) -> 'a Lwt.t

val register_service : Core.Registry.Binding.t -> unit Lwt.t

val just_service : (module Sig.SERVICE) -> (module Sig.SERVICE) Lwt.t
