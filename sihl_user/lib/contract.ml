module type REPOSITORY = sig
  include Sihl.Contract.REPOSITORY

  module User : sig
    val get_all : Sihl.Db.connection -> Model.User.t list Sihl.Db.db_result

    val get : id:string -> Sihl.Db.connection -> Model.User.t Sihl.Db.db_result

    val get_by_email :
      email:string -> Sihl.Db.connection -> Model.User.t Sihl.Db.db_result

    val insert : Model.User.t -> Sihl.Db.connection -> unit Sihl.Db.db_result

    val update : Model.User.t -> Sihl.Db.connection -> unit Sihl.Db.db_result
  end

  module Token : sig
    val get :
      value:string -> Sihl.Db.connection -> Model.Token.t Sihl.Db.db_result

    val delete_by_user :
      id:string -> Sihl.Db.connection -> unit Sihl.Db.db_result

    val insert : Model.Token.t -> Sihl.Db.connection -> unit Sihl.Db.db_result

    val update : Model.Token.t -> Sihl.Db.connection -> unit Sihl.Db.db_result
  end
end
