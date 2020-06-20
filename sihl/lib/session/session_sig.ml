open Base

module type REPO = sig
  include Sig.REPO

  val get_all : Core.Db.connection -> Session_model.t list Core.Db.db_result

  val get :
    key:string -> Core.Db.connection -> Session_model.t option Core.Db.db_result

  val insert : Session_model.t -> Core.Db.connection -> unit Core.Db.db_result

  val update : Session_model.t -> Core.Db.connection -> unit Core.Db.db_result

  val delete : key:string -> Core.Db.connection -> unit Core.Db.db_result
end

module type SERVICE = sig
  include Service.SERVICE

  val set_value :
    Opium_kernel.Request.t ->
    key:string ->
    value:string ->
    (unit, string) Result.t Lwt.t

  val remove_value :
    Opium_kernel.Request.t -> key:string -> (unit, string) Result.t Lwt.t

  val get_value :
    Opium_kernel.Request.t ->
    key:string ->
    (string option, string) Result.t Lwt.t

  val get_session :
    Opium_kernel.Request.t ->
    key:string ->
    (Session_model.t option, string) Result.t Lwt.t

  val get_all_sessions :
    Opium_kernel.Request.t -> (Session_model.t list, string) Result.t Lwt.t

  val insert_session :
    Opium_kernel.Request.t ->
    session:Session_model.t ->
    (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.Key.t =
  Core.Container.Key.create "session.service"

let middleware_key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("session.key", fun _ -> sexp_of_string "session.key")
