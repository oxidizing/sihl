module Session = struct
  open Base
  open Model.Session

  let t =
    let encode m =
      let data = m.data |> string_of_data in
      Ok (m.key, data, m.expire_date)
    in
    let decode (key, data, expire_date) =
      match data |> data_of_string with
      | Ok data -> Ok { key; data; expire_date }
      | Error msg -> Error msg
    in
    Caqti_type.(custom ~encode ~decode (tup3 string string ptime))
end

module type REPOSITORY = sig
  include Sihl.Core.Contract.REPOSITORY

  val get_all :
    Sihl.Core.Db.connection -> Model.Session.t list Sihl.Core.Db.db_result

  val get :
    key:string ->
    Sihl.Core.Db.connection ->
    Model.Session.t option Sihl.Core.Db.db_result

  val insert :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val update :
    Model.Session.t -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result

  val delete :
    key:string -> Sihl.Core.Db.connection -> unit Sihl.Core.Db.db_result
end
