module type SERVICE = sig
  include Sig.SERVICE

  val base64 : bytes:int -> string
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "random"
