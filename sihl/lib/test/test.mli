val request_with_connection : unit -> Opium.Std.Request.t Lwt.t

val seed : (Opium.Std.Request.t -> 'a Lwt.t) -> 'a Lwt.t

val register_services : Core.Container.binding list -> unit Lwt.t

val just_services : (module Sig.SERVICE) list -> (module Sig.SERVICE) Lwt.t
