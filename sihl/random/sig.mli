module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Generate [nr] random bytes *)
  val bytes : nr:int -> char list

  (** Generate a random base64 string containing [nr] of bytes that is safe to use in
      URIs. *)
  val base64 : nr:int -> string

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
