module type REPOSITORY = sig
  include Data.Repo.Service.Sig.REPO

  val find : Core.Ctx.t -> value:string -> Token_core.t Lwt.t
  val find_opt : Core.Ctx.t -> value:string -> Token_core.t option Lwt.t
  val insert : Core.Ctx.t -> token:Token_core.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Create a token and store a token.

      Provide [expires_in] to define a duration in which the token is valid, default is
      one day. Provide [data] to store optional data as string. *)
  val create
    :  Core.Ctx.t
    -> kind:string
    -> ?data:string
    -> ?expires_in:Utils.Time.duration
    -> unit
    -> Token_core.t Lwt.t

  (** Returns an active and non-expired token. *)
  val find : Core.Ctx.t -> string -> Token_core.t Lwt.t

  (** Returns an active and non-expired token. *)
  val find_opt : Core.Ctx.t -> string -> Token_core.t option Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
