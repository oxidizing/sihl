module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val find : Core.Ctx.t -> value:string -> (Token_core.t, string) Result.t Lwt.t

  val find_opt :
    Core.Ctx.t -> value:string -> (Token_core.t option, string) Result.t Lwt.t

  val insert : Core.Ctx.t -> token:Token_core.t -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val create :
    Core.Ctx.t ->
    kind:string ->
    ?data:string ->
    ?expires_in:Utils.Time.duration ->
    unit ->
    (Token_core.t, string) Result.t Lwt.t

  val find :
    Core.Ctx.t -> value:string -> unit -> (Token_core.t, string) Result.t Lwt.t
  (** Returns an active and non-expired token *)

  val find_opt :
    Core.Ctx.t ->
    value:string ->
    unit ->
    (Token_core.t option, string) Result.t Lwt.t
  (** Returns an active and non-expired token *)
end
