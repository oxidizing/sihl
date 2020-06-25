module Req = Http_req
module Res = Http_res
module Cookie = Http_cookie

val handle : ('a -> Res.t Lwt.t) -> 'a -> Opium_kernel.Response.t Lwt.t

val get : string -> (Opium_kernel.Request.t -> Res.t Lwt.t) -> Opium.App.builder

val post :
  string -> (Opium_kernel.Request.t -> Res.t Lwt.t) -> Opium.App.builder

val delete :
  string -> (Opium_kernel.Request.t -> Res.t Lwt.t) -> Opium.App.builder

val put : string -> (Opium_kernel.Request.t -> Res.t Lwt.t) -> Opium.App.builder

val all : string -> (Opium_kernel.Request.t -> Res.t Lwt.t) -> Opium.App.builder

val ctx : Opium_kernel.Request.t -> Core_ctx.t
