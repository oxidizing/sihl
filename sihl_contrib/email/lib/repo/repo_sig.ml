module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  val get :
    id:string ->
    Sihl.Core.Db.connection ->
    Sihl.Email.Template.t Sihl.Core.Db.db_result
end
