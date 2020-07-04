val with_services : Core.Ctx.t -> Core.Container.binding list -> unit Lwt.t

val seed : (Core.Ctx.t -> ('a, string) Result.t Lwt.t) -> 'a Lwt.t

val context : ?user:User.t -> unit -> Core.Ctx.t

val start_app : (module App_sig.APP) -> unit Lwt.t

val stop_app : unit -> unit Lwt.t

val clean : unit -> unit Lwt.t

val migrate : unit -> unit Lwt.t
