module Res = Web_res

type handler = Core.Ctx.t -> Res.t Lwt.t [@@deriving show]

let equal_handler _ _ = true

type meth = Get | Post | Put | Delete | All [@@deriving show, eq]

type t = meth * string * handler [@@deriving show, eq]

let handler (_, _, handler) = handler

let set_handler handler (meth, path, _) = (meth, path, handler)

let get path handler = (Get, path, handler)

let post path handler = (Post, path, handler)

let put path handler = (Put, path, handler)

let delete path handler = (Delete, path, handler)

let all path handler = (All, path, handler)

let prefix prefix (meth, path, handler) = (meth, prefix ^ path, handler)

let handler_to_opium_handler handler opium_req =
  Core.Ctx.empty
  |> Web_req.add_to_ctx opium_req
  |> handler |> Lwt.map Web_res.to_opium

let to_opium_builder (meth, path, handler) =
  let handler = handler_to_opium_handler handler in
  match meth with
  | Get -> Opium.Std.get path handler
  | Post -> Opium.Std.post path handler
  | Put -> Opium.Std.put path handler
  | Delete -> Opium.Std.delete path handler
  | All -> Opium.Std.all path handler
