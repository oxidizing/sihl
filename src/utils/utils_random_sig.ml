module type SERVICE = sig
  include Core_container.SERVICE

  val base64 : bytes:int -> string
end
