module Req = Web_req
module Res = Web_res

type handler = Req.t -> (Res.t, Core_fail.error) Result.t Lwt.t
[@@deriving show]

let equal_handler _ _ = true

type meth = Get | Post | Put | Delete | All [@@deriving show, eq]

type t = meth * string * handler [@@deriving show, eq]

let get path handler = (Get, path, handler)

let post path handler = (Post, path, handler)

let put path handler = (Put, path, handler)

let delete path handler = (Delete, path, handler)

let all path handler = (All, path, handler)
