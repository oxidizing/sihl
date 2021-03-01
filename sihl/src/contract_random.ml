let name = "random"

module type Sig = sig
  (** [bytes n] generates a string that comprises [n] random bytes. *)
  val bytes : int -> char list

  (** [base64 n] generates a base64 encoded string that comprises [n] random
      bytes. *)
  val base64 : int -> string

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
