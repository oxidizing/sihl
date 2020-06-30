module type REPOSITORY = sig
  include Sig.REPO

  val get :
    value:string ->
    Core.Db.connection ->
    (Token_model.t option, string) Result.t Lwt.t

  val delete_by_user :
    id:string -> Core.Db.connection -> (unit, string) Result.t Lwt.t

  val insert :
    Token_model.t -> Core.Db.connection -> (unit, string) Result.t Lwt.t

  val update :
    Token_model.t -> Core.Db.connection -> (unit, string) Result.t Lwt.t
end
