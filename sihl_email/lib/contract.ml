module type REPOSITORY = sig
  val get :
    id:string ->
    Sihl_core.Db.connection ->
    Model.Template.t Sihl_core.Db.db_result

  val clean : Sihl_core.Db.connection -> unit Sihl_core.Db.db_result
end

let migration :
    (module Sihl_core.Contract.Migration.MIGRATION) Sihl_core.Registry.Key.t =
  Sihl_core.Registry.Key.create "emails migration"

let repository : (module REPOSITORY) Sihl_core.Registry.Key.t =
  Sihl_core.Registry.Key.create "email template repository"

let transport :
    (module Sihl_core.Contract.Email.EMAIL with type email = Model.Email.t)
    Sihl_core.Registry.Key.t =
  Sihl_core.Registry.Key.create "email transport"
