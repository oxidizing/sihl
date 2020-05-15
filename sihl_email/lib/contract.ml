module type REPOSITORY = sig
  include Sihl.Contract.REPOSITORY

  val get :
    id:string -> Sihl.Db.connection -> Model.Template.t Sihl.Db.db_result
end
