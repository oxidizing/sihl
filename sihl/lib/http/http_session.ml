module type SESSION_SERVICE = sig
  val set :
    key:string ->
    value:string ->
    Opium_kernel.Request.t ->
    (unit, Core_error.t) Result.t Lwt.t

  val remove :
    key:string -> Opium_kernel.Request.t -> (unit, Core_error.t) Result.t Lwt.t

  val get :
    string ->
    Opium_kernel.Request.t ->
    (string option, Core_error.t) Result.t Lwt.t
end

let registry_key : (module SESSION_SERVICE) Core.Registry.Key.t =
  Core.Registry.Key.create "session.service"

let key = registry_key

let set ~key ~value req =
  match Core.Registry.get_opt registry_key with
  | Some (module Service : SESSION_SERVICE) -> Service.set ~key ~value req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Core_error.internal () |> Result.error |> Lwt.return

let remove ~key req =
  match Core.Registry.get_opt registry_key with
  | Some (module Service : SESSION_SERVICE) -> Service.remove ~key req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Core_error.internal () |> Result.error |> Lwt.return

let get key req =
  match Core.Registry.get_opt registry_key with
  | Some (module Service : SESSION_SERVICE) -> Service.get key req
  | None ->
      let msg =
        "SESSION: Could not find session service, have you installed the \
         session app?"
      in
      Logs.err (fun m -> m "%s" msg);
      Core_error.internal () |> Result.error |> Lwt.return
