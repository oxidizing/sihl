module type REPOSITORY = sig
  include Sihl_core.Contract.REPOSITORY

  module User : sig
    val get_all :
      Sihl_core.Db.connection -> Model.User.t list Sihl_core.Db.db_result

    val get :
      id:string ->
      Sihl_core.Db.connection ->
      Model.User.t Sihl_core.Db.db_result

    val get_by_email :
      email:string ->
      Sihl_core.Db.connection ->
      Model.User.t Sihl_core.Db.db_result

    val insert :
      Model.User.t -> Sihl_core.Db.connection -> unit Sihl_core.Db.db_result

    val update :
      Model.User.t -> Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
  end

  module Token : sig
    val get :
      value:string ->
      Sihl_core.Db.connection ->
      Model.Token.t Sihl_core.Db.db_result

    val delete_by_user :
      id:string -> Sihl_core.Db.connection -> unit Sihl_core.Db.db_result

    val insert :
      Model.Token.t -> Sihl_core.Db.connection -> unit Sihl_core.Db.db_result

    val update :
      Model.Token.t -> Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
  end

  val migrate : unit -> Sihl_core.Contract.Migration.migration

  val clean : Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
end
