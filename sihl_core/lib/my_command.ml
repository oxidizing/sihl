type fn = Opium.Std.Request.t -> string list -> string -> unit Lwt.t

type t = { name : string; description : string; fn : fn }

let find _ _ =
  Some
    { name = "TODO"; description = "TODO"; fn = (fun _ _ _ -> Lwt.return ()) }

let help _ = "TODO"
