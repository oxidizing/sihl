type fn = Opium.Std.Request.t -> string list -> string -> unit Lwt.t

type t = { name : string; description : string; fn : fn }
