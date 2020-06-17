module Req = Http_req
module Res = Http_res
module Cookie = Http_cookie
module Session = Http_session
module Middleware = Http_middleware

val handle :
  (Opium_kernel.Request.t -> Res.t Lwt.t) ->
  Opium_kernel.Request.t ->
  Opium_kernel.Response.t Lwt.t

val get :
  string ->
  (Opium_kernel.Request.t -> (Res.t, Core_error.t) Result.t Lwt.t) ->
  Opium.App.builder

val post :
  string ->
  (Opium_kernel.Request.t -> (Res.t, Core_error.t) Result.t Lwt.t) ->
  Opium.App.builder

val delete :
  string ->
  (Opium_kernel.Request.t -> (Res.t, Core_error.t) Result.t Lwt.t) ->
  Opium.App.builder

val put :
  string ->
  (Opium_kernel.Request.t -> (Res.t, Core_error.t) Result.t Lwt.t) ->
  Opium.App.builder

val all :
  string ->
  (Opium_kernel.Request.t -> (Res.t, Core_error.t) Result.t Lwt.t) ->
  Opium.App.builder
