open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Create a token and store a token.

      Provide [expires_in] to define a duration in which the token is valid, default is
      one day. Provide [data] to store optional data as string. Provide [length] to define
      the length of the token in bytes. *)
  val create
    :  kind:string
    -> ?data:string
    -> ?expires_in:Sihl_core.Time.duration
    -> ?length:int
    -> unit
    -> Token.t Lwt.t

  (** Returns an active and non-expired token. Raises [Failure] if no token is found. *)
  val find : string -> Token.t Lwt.t

  (** Returns an active and non-expired token. *)
  val find_opt : string -> Token.t option Lwt.t

  (** Returns an active and non-expired token by id. Raises [Failure] if no token is
      found. *)
  val find_by_id : string -> Token.t Lwt.t

  (** Returns an active and non-expired token by id. *)
  val find_by_id_opt : string -> Token.t option Lwt.t

  (** Invalidate a token by marking it as such in the database and therefore marking it
      "to be deleted" *)
  val invalidate : Token.t -> unit Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
