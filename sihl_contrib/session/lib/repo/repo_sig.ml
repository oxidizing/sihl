module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  val get_all :
    Sihl.Core.Db.connection -> Model.Session.t list Sihl.Core.Db.db_result

  val get :
    id:string ->
    Sihl.Core.Db.connection ->
    Model.Session.t option Sihl.Core.Db.db_result

  val insert :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val update :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val delete :
    id:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
end
