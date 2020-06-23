val request_with_connection : unit -> Opium.Std.Request.t Lwt.t

val register_services : Core.Container.binding list -> unit Lwt.t

val seed : (Opium.Std.Request.t -> ('a, string) Result.t Lwt.t) -> 'a Lwt.t
