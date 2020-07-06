open Base
include Session_model
module Sig = Session_sig
module Service = Session_service
module Schedule = Session_schedule

let ctx_key : t Core.Ctx.key = Core.Ctx.create_key ()

let add_to_ctx session ctx = Core.Ctx.add ctx_key session ctx

let set_value req ~key ~value =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.set_value ~key ~value req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let remove_value req ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.remove_value ~key req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_value req ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.get_value ~key req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let get_session req ~key =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.get_session req ~key
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let insert_session req ~session =
  match Core.Container.fetch_service Sig.key with
  | Some (module Service : Sig.SERVICE) -> Service.insert_session req ~session
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg
