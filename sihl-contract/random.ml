let name = "random"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** [bytes n] generates a string that comprises [n] random bytes. *)
  val bytes : int -> char list

  (** [base64 n] generates a base64 encoded string that comprises [n] random
      bytes. *)
  val base64 : int -> string

  val register : unit -> Sihl_core.Container.Service.t
end
