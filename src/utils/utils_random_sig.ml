module type SERVICE = sig
  include Core_container.SERVICE

  val base64 : bytes:int -> string
  (** Returns a base64 string containing number of [bytes] that is safe to use in URIs. *)
end
