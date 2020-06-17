type t

val project_ref : t

val start : t -> (unit, Core.Error.t) Result.t Lwt.t

val stop : unit -> (unit, Core.Error.t) Result.t Lwt.t

val clean : unit -> (unit, Core.Error.t) Result.t Lwt.t

val migrate : unit -> (unit, Core.Error.t) Result.t Lwt.t
