module type SESSION_SERVICE = sig
  val set :
    key:string ->
    value:string ->
    Opium_kernel.Request.t ->
    (unit, Core_error.t) Result.t Lwt.t

  val remove :
    key:string -> Opium_kernel.Request.t -> (unit, Core_error.t) Result.t Lwt.t

  val get :
    string ->
    Opium_kernel.Request.t ->
    (string option, Core_error.t) Result.t Lwt.t
end

val key : (module SESSION_SERVICE) Core.Registry.Key.t

val set :
  key:string ->
  value:string ->
  Opium_kernel.Request.t ->
  (unit, Core_error.t) Result.t Lwt.t

val remove :
  key:string -> Opium_kernel.Request.t -> (unit, Core_error.t) Result.t Lwt.t

val get :
  string ->
  Opium_kernel.Request.t ->
  (string option, Core_error.t) Result.t Lwt.t
