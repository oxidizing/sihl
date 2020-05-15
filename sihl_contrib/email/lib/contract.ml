module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  val get :
    id:string ->
    Sihl.Core.Db.connection ->
    Model.Template.t Sihl.Core.Db.db_result
end
