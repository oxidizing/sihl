val register_services : Core.Container.binding list -> unit Lwt.t

val seed : (Core.Ctx.t -> ('a, string) Result.t Lwt.t) -> 'a Lwt.t

val context : ?user:User.t -> unit -> Core.Ctx.t
