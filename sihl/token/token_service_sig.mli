module type REPOSITORY = sig
  include Data.Repo.Service.Sig.REPO

  val find_opt : Core.Ctx.t -> value:string -> Token_core.t option Lwt.t
  val find_by_id_opt : Core.Ctx.t -> id:string -> Token_core.t option Lwt.t
  val insert : Core.Ctx.t -> token:Token_core.t -> unit Lwt.t
  val update : Core.Ctx.t -> token:Token_core.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Create a token and store a token.

      Provide [expires_in] to define a duration in which the token is valid, default is
      one day. Provide [data] to store optional data as string. Provide [length] to define
      the length of the token in bytes. *)
  val create
    :  Core.Ctx.t
    -> kind:string
    -> ?data:string
    -> ?expires_in:Utils.Time.duration
    -> ?length:int
    -> unit
    -> Token_core.t Lwt.t

  (** Returns an active and non-expired token. Raises [Failure] if no token is found. *)
  val find : Core.Ctx.t -> string -> Token_core.t Lwt.t

  (** Returns an active and non-expired token. *)
  val find_opt : Core.Ctx.t -> string -> Token_core.t option Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t

  (** Returns an active and non-expired token by id. Raises [Failure] if no token is
      found. *)
  val find_by_id : Core.Ctx.t -> string -> Token_core.t Lwt.t

  (** Returns an active and non-expired token by id. *)
  val find_by_id_opt : Core.Ctx.t -> string -> Token_core.t option Lwt.t

  (** Invalidate a token by marking it as such in the database and therefore marking it
      "to be deleted" *)
  val invalidate : Core.Ctx.t -> Token_core.t -> unit Lwt.t
end
