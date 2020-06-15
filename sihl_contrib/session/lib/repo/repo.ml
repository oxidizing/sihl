module type REPOSITORY = sig
  include Sihl.Sig.REPO

  val get_all :
    Sihl.Core.Db.connection -> Sihl.Session.t list Sihl.Core.Db.db_result

  val get :
    key:string ->
    Sihl.Core.Db.connection ->
    Sihl.Session.t option Sihl.Core.Db.db_result

  val insert :
    Sihl.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val update :
    Sihl.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val delete :
    key:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
end
