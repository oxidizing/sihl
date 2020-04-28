module type REPOSITORY = sig
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

  val clean : Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
end

let repository : (module REPOSITORY) Sihl_core.Registry.Key.t =
  Sihl_core.Registry.Key.create "users repository"

let migration :
    (module Sihl_core.Contract.Migration.MIGRATION) Sihl_core.Registry.Key.t =
  Sihl_core.Registry.Key.create "users migration"
