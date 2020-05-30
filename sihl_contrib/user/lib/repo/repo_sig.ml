module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  module User : sig
    val get_all :
      Sihl.Core.Db.connection -> Sihl.User.t list Sihl.Core.Db.db_result

    val get :
      id:string -> Sihl.Core.Db.connection -> Sihl.User.t Sihl.Core.Db.db_result

    val get_by_email :
      email:string ->
      Sihl.Core.Db.connection ->
      Sihl.User.t Sihl.Core.Db.db_result

    val insert :
      Sihl.User.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

    val update :
      Sihl.User.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
  end

  module Token : sig
    val get :
      value:string ->
      Sihl.Core.Db.connection ->
      Model.Token.t Sihl.Core.Db.db_result

    val delete_by_user :
      id:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

    val insert :
      Model.Token.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

    val update :
      Model.Token.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
  end
end
