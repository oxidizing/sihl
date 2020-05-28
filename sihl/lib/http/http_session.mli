module type SESSION_SERVICE = sig
  val set : key:string -> value:string -> Opium_kernel.Request.t -> unit Lwt.t

  val get : string -> Opium_kernel.Request.t -> string option Lwt.t
end

val key : (module SESSION_SERVICE) Core.Registry.Key.t

val set : key:string -> value:string -> Opium_kernel.Request.t -> unit Lwt.t

val get : string -> Opium_kernel.Request.t -> string option Lwt.t
