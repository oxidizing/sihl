module type REPOSITORY = sig
  include Sihl_core.Contract.REPOSITORY

  val get :
    id:string ->
    Sihl_core.Db.connection ->
    Model.Template.t Sihl_core.Db.db_result
end
