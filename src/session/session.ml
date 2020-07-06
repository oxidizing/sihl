open Base
include Session_model
module Sig = Session_sig
module Service = Session_service
module Schedule = Session_schedule

let add_to_ctx session ctx =
  Core.Ctx.add Sig.ctx_session_key (Session_model.key session) ctx

let set_value ctx ~key ~value =
  Logs.debug (fun m -> m "three %s" (Core.Ctx.id ctx));
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.set_value ~key ~value ctx
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let remove_value ctx ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.remove_value ~key ctx
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_value ctx ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.get_value ~key ctx
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_session ctx ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.get_session ctx ~key
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_all_sessions ctx =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.get_all_sessions ctx
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let insert_session ctx ~session =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.insert_session ctx ~session
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg
