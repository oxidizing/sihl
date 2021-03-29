let name = "random"

module type Sig = sig
  (** [base64 n] returns a Base64 encoded string containing [n] random bytes. *)
  val base64 : int -> string

  (** [bytes n] returns a byte sequence as string with [n] random bytes. In most
      cases you want to use {!base64} to get a string that can be used safely in
      most web contexts.*)
  val bytes : int -> string

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
