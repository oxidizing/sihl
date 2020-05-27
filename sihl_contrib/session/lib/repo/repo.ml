module Session = struct
  open Base
  open Model.Session

  let t =
    let encode m =
      let data =
        m.data |> Map.to_alist |> map_to_yojson |> Yojson.Safe.to_string
      in
      Ok (m.key, data, m.expire_date)
    in
    let decode (key, data, expire_date) =
      let data =
        data |> Yojson.Safe.from_string |> map_of_yojson
        |> Result.ok_or_failwith
        |> Map.of_alist_exn (module String)
      in
      Ok { key; data; expire_date }
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
