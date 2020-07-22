module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val find :
    value:string ->
    Data_db_core.connection ->
    (Token_core.t, string) Result.t Lwt.t

  val find_opt :
    value:string ->
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
end
