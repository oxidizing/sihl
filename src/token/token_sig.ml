module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val find :
    value:string ->
    ?any:bool ->
    Data_db_core.connection ->
    (Token_core.t, string) Result.t Lwt.t

  val find_opt :
    value:string ->
    ?any:bool ->
    Data_db_core.connection ->
    (Token_core.t option, string) Result.t Lwt.t

  val insert :
    token:Token_core.t ->
    Data_db_core.connection ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val create :
    Core.Ctx.t ->
    kind:string ->
    data:string ->
    expires_in:Utils.Time.duration ->
    (Token_core.t, string) Result.t Lwt.t

  val find :
    Core.Ctx.t ->
    ?any:bool ->
    value:string ->
    unit ->
    (Token_core.t, string) Result.t Lwt.t
  (** If [any] is true, all the stored tokens are returned. If [any] is false, only tokens that have not expired and that have status "active" are returned. [any] is false by default. *)

  val find_opt :
    Core.Ctx.t ->
    ?any:bool ->
    value:string ->
    unit ->
    (Token_core.t option, string) Result.t Lwt.t
  (** If [any] is true, all the stored tokens are returned. If [any] is false, only tokens that have not expired and that have status "active" are returned. [any] is false by default. *)
end
