type handler = Core.Ctx.t -> Res.t Lwt.t [@@deriving show]

let equal_handler _ _ = true

type meth = Get | Post | Put | Delete | All [@@deriving show, eq]

type t = meth * string * handler [@@deriving show, eq]

let meth (meth, _, _) = meth

let path (_, path, _) = path

let handler (_, _, handler) = handler

let set_handler handler (meth, path, _) = (meth, path, handler)

let get path handler = (Get, path, handler)

let post path handler = (Post, path, handler)

let put path handler = (Put, path, handler)

let delete path handler = (Delete, path, handler)

let all path handler = (All, path, handler)

let prefix prefix (meth, path, handler) = (meth, prefix ^ path, handler)
