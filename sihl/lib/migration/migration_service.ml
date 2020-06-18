open Base

module Model = struct
  type t = { namespace : string; version : int; dirty : bool }

  let create ~namespace = { namespace; version = 0; dirty = true }

  let mark_dirty state = { state with dirty = true }

  let mark_clean state = { state with dirty = false }

  let increment state = { state with version = state.version + 1 }

  let steps_to_apply (namespace, steps) { version; _ } =
    (namespace, List.drop steps version)

  let of_tuple (namespace, version, dirty) = { namespace; version; dirty }

  let to_tuple state = (state.namespace, state.version, state.dirty)

  let dirty state = state.dirty
end

module type SERVICE = sig
  val setup : Core.Db.connection -> (unit, string) Lwt_result.t

  val has :
    Core.Db.connection -> namespace:string -> (bool, string) Lwt_result.t

  val get :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val upsert : Core.Db.connection -> Model.t -> (unit, string) Lwt_result.t

  val mark_dirty :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val mark_clean :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val increment :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val provide_repo : Sig.repo option
end
