type t = { name : string; description : string; fn : Core.Ctx.t -> unit Lwt.t }
[@@deriving fields]

let show seed = Printf.sprintf "%s - %s" seed.name seed.description
