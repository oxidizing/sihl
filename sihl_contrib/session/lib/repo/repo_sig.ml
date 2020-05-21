module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  val exists :
    id:string -> Sihl.Core.Db.connection -> bool Sihl.Core.Db.db_result

  val get :
    id:string ->
    Sihl.Core.Db.connection ->
    Model.Session.t Sihl.Core.Db.db_result

  val insert :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val update :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val delete :
    id:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
end
