open Lwt.Syntax

module Make (RandomService : Utils.Random.Service.Sig.SERVICE) (Repo : Sig.REPOSITORY) :
  Sig.SERVICE = struct
  let find_opt ctx value =
    let* token = Repo.find_opt ctx ~value in
    Lwt.return @@ Option.bind token (fun tk -> if Model.is_valid tk then token else None)
  ;;

  let find ctx value =
    let* token = find_opt ctx value in
    match token with
    | Some token -> Lwt.return token
    | None ->
      raise (Model.Exception (Printf.sprintf "Token %s not found or not valid" value))
  ;;

  let find_by_id_opt ctx id =
    let* token = Repo.find_by_id_opt ctx ~id in
    Lwt.return @@ Option.bind token (fun tk -> if Model.is_valid tk then token else None)
  ;;

  let find_by_id ctx id =
    let* token = find_by_id_opt ctx id in
    match token with
    | Some token -> Lwt.return token
    | None ->
      raise
        (Model.Exception (Printf.sprintf "Token with id %s not found or not valid" id))
  ;;

  let make ~id ~data ~kind ?(expires_in = Utils.Time.OneDay) ?now ?(length = 80) () =
    let value = RandomService.base64 ~bytes:length in
    let expires_in = Utils.Time.duration_to_span expires_in in
    let now = Option.value ~default:(Ptime_clock.now ()) now in
    let expires_at = Option.get (Ptime.add_span now expires_in) in
    let status = Model.Status.Active in
    let created_at = Ptime_clock.now () in
    Model.make ~id ~value ~data ~kind ~status ~expires_at ~created_at
  ;;

  let create ctx ~kind ?data ?expires_in ?length () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let length = Option.value ~default:80 length in
    let id = Database.Id.random () |> Database.Id.to_string in
    let token = make ~id ~kind ~data ~expires_in ~length () in
    let* () = Repo.insert ctx ~token in
    let value = Model.value token in
    find ctx value
  ;;

  let invalidate ctx token = Repo.update ctx ~token:(Model.invalidate token)

  let start ctx =
    let () = Repo.register_migration () in
    let () = Repo.register_cleaner () in
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "token" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
