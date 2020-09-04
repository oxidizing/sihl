module type SERVICE = sig
  include Core.Container.SERVICE

  val base64 : bytes:int -> string
  (** Generate a base64 string containing number of [bytes] that is safe to use in URIs. *)
end
