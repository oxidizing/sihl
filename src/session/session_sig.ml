open Base

module type REPO = sig
  include Data.Repo.Sig.REPO

  val get_all :
    Data_db_core.connection -> (Session_model.t list, string) Result.t Lwt.t

  val get :
    key:string ->
    Data_db_core.connection ->
    (Session_model.t option, string) Result.t Lwt.t

  val insert :
    Session_model.t -> Data_db_core.connection -> (unit, string) Result.t Lwt.t

  val update :
    Session_model.t -> Data_db_core.connection -> (unit, string) Result.t Lwt.t

  val delete :
    key:string -> Data_db_core.connection -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val set_value :
    Core.Ctx.t -> key:string -> value:string -> (unit, string) Result.t Lwt.t

  val remove_value : Core.Ctx.t -> key:string -> (unit, string) Result.t Lwt.t

  val get_value :
    Core.Ctx.t -> key:string -> (string option, string) Result.t Lwt.t

  val get_session :
    Core.Ctx.t -> key:string -> (Session_model.t option, string) Result.t Lwt.t

  val require_session_key : Core.Ctx.t -> (string, string) Result.t Lwt.t

  val get_all_sessions :
    Core.Ctx.t -> (Session_model.t list, string) Result.t Lwt.t

  val insert_session :
    Core.Ctx.t -> session:Session_model.t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "session.service"

let middleware_key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("session.key", fun _ -> sexp_of_string "session.key")

let ctx_session_key : string Core.Ctx.key = Core.Ctx.create_key ()