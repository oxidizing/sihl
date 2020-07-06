module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val get :
    value:string ->
    Data_db_core.connection ->
    (Token_model.t option, string) Result.t Lwt.t

  val delete_by_user :
    id:string -> Data_db_core.connection -> (unit, string) Result.t Lwt.t

  val insert :
    Token_model.t -> Data_db_core.connection -> (unit, string) Result.t Lwt.t

  val update :
    Token_model.t -> Data_db_core.connection -> (unit, string) Result.t Lwt.t
end
