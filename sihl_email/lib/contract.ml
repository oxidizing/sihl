module type REPOSITORY = sig
  val get :
    id:string ->
    Sihl_core.Db.connection ->
    Model.Template.t Sihl_core.Db.db_result

  val migrate : unit -> Sihl_core.Contract.Migration.migration

  val clean : Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
end
