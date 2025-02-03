let log_src = Logs.Src.create ("sihl.service." ^ Sihl.Contract.Token.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Repo.Sig) : Sihl.Contract.Token.Sig = struct
  type config = { token_length : int option }

  let config token_length = { token_length }

  let schema =
    let open Conformist in
    make [ optional (int ~default:80 "TOKEN_LENGTH") ] config
  ;;

  let is_valid_token token =
    let open Repo.Model in
    String.equal
      (Status.to_string token.status)
      (Status.to_string Status.Active)
    && Ptime.is_later token.expires_at ~than:(Ptime_clock.now ())
  ;;

  let make id ?(expires_in = Sihl.Time.OneDay) ?now ?(length = 80) data =
    let open Repo.Model in
    let value = Sihl.Random.base64 length in
    let expires_in = Sihl.Time.duration_to_span expires_in in
    let now = Option.value ~default:(Ptime_clock.now ()) now in
    let expires_at =
      match Ptime.add_span now expires_in with
      | Some expires_at -> expires_at
      | None -> failwith ("Could not parse expiry date for token with id " ^ id)
    in
    let status = Status.Active in
    let created_at = Ptime_clock.now () in
    { id; value; data; status; expires_at; created_at }
  ;;

  let create ?ctx ?secret:_ ?expires_in data =
    let open Repo.Model in
    let id = Sihl.Random.Uuid.create () in
    let length =
      Option.value ~default:30 (Sihl.Configuration.read schema).token_length
    in
    let token = make id ?expires_in ~length data in
    let%lwt () = Repo.insert ?ctx token in
    Repo.find_by_id ?ctx id |> Lwt.map (fun token -> token.value)
  ;;

  let read ?ctx ?secret:_ ?force token_value ~k =
    let open Repo.Model in
    let%lwt token = Repo.find_opt ?ctx token_value in
    match token with
    | None -> Lwt.return None
    | Some token ->
      (match is_valid_token token, force with
       | true, _ | false, Some () ->
         (match
            List.find_opt (fun (key, _) -> String.equal k key) token.data
          with
          | Some (_, value) -> Lwt.return (Some value)
          | None -> Lwt.return None)
       | false, None -> Lwt.return None)
  ;;

  let read_all ?ctx ?secret:_ ?force token =
    let open Repo.Model in
    let%lwt token = Repo.find ?ctx token in
    match is_valid_token token, force with
    | true, _ | false, Some () -> Lwt.return (Some token.data)
    | false, None -> Lwt.return None
  ;;

  let verify ?ctx ?secret:_ token =
    let%lwt token = Repo.find_opt ?ctx token in
    match token with
    | Some _ -> Lwt.return true
    | None -> Lwt.return false
  ;;

  let deactivate ?ctx token =
    let open Repo.Model in
    let%lwt token = Repo.find ?ctx token in
    let updated = { token with status = Status.Inactive } in
    Repo.update ?ctx updated
  ;;

  let activate ?ctx token =
    let open Repo.Model in
    let%lwt token = Repo.find ?ctx token in
    let updated = { token with status = Status.Active } in
    Repo.update ?ctx updated
  ;;

  let is_active ?ctx token =
    let open Repo.Model in
    let%lwt token = Repo.find ?ctx token in
    match token.status with
    | Status.Active -> Lwt.return true
    | Status.Inactive -> Lwt.return false
  ;;

  let is_expired ?ctx ?secret:_ token =
    let open Repo.Model in
    let%lwt token = Repo.find ?ctx token in
    Lwt.return (Ptime.is_earlier token.expires_at ~than:(Ptime_clock.now ()))
  ;;

  let is_valid ?ctx ?secret:_ token =
    let open Repo.Model in
    let%lwt token = Repo.find_opt ?ctx token in
    match token with
    | None -> Lwt.return false
    | Some token ->
      (match token.status with
       | Status.Inactive -> Lwt.return false
       | Status.Active ->
         Lwt.return (Ptime.is_later token.expires_at ~than:(Ptime_clock.now ())))
  ;;

  let start () =
    (* Make sure that configuration is valid *)
    Sihl.Configuration.require schema;
    Lwt.return ()
  ;;

  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Token.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    let configuration = Sihl.Configuration.make ~schema () in
    Sihl.Container.Service.create ~configuration lifecycle
  ;;
end

module MakeJwt (Repo : Blacklist_repo.Sig) : Sihl.Contract.Token.Sig = struct
  let calculate_exp expires_in =
    Sihl.Time.date_from_now (Ptime_clock.now ()) expires_in
    |> Ptime.to_float_s
    |> Int.of_float
    |> string_of_int
  ;;

  let create ?ctx:_ ?secret ?(expires_in = Sihl.Time.OneWeek) data =
    let secret =
      Option.value ~default:(Sihl.Configuration.read_secret ()) secret
    in
    let data =
      match List.find_opt (fun (k, _) -> String.equal k "exp") data with
      | Some (_, v) ->
        (match int_of_string_opt v with
         | Some _ -> data
         | None ->
           let exp = calculate_exp expires_in in
           List.cons ("exp", exp) data)
      | None ->
        let exp = calculate_exp expires_in in
        List.cons ("exp", exp) data
    in
    match Jwto.encode HS512 secret data with
    | Error msg -> raise @@ Sihl.Contract.Token.Exception msg
    | Ok token -> Lwt.return token
  ;;

  let deactivate ?ctx:_ token = Repo.insert token
  let activate ?ctx:_ token = Repo.delete token
  let is_active ?ctx:_ token = Repo.has token |> Lwt.map not

  let read ?ctx:_ ?secret ?force token_value ~k =
    let secret =
      Option.value ~default:(Sihl.Configuration.read_secret ()) secret
    in
    match Jwto.decode_and_verify secret token_value, force with
    | Error msg, None ->
      Logs.warn (fun m -> m "Failed to decode and verify token: %s" msg);
      Lwt.return None
    | Ok token, None ->
      let%lwt is_active = is_active token_value in
      if is_active
      then (
        match
          List.find_opt
            (fun (key, _) -> String.equal k key)
            (Jwto.get_payload token)
        with
        | Some (_, value) -> Lwt.return (Some value)
        | None -> Lwt.return None)
      else Lwt.return None
    | Ok token, Some () ->
      (match
         List.find_opt
           (fun (key, _) -> String.equal k key)
           (Jwto.get_payload token)
       with
       | Some (_, value) -> Lwt.return (Some value)
       | None -> Lwt.return None)
    | Error msg, Some () ->
      Logs.warn (fun m -> m "Failed to decode and verify token: %s" msg);
      (match Jwto.decode token_value with
       | Error msg ->
         Logs.warn (fun m -> m "Failed to decode token: %s" msg);
         Lwt.return None
       | Ok token ->
         (match
            List.find_opt
              (fun (key, _) -> String.equal k key)
              (Jwto.get_payload token)
          with
          | Some (_, value) -> Lwt.return (Some value)
          | None -> Lwt.return None))
  ;;

  let read_all ?ctx:_ ?secret ?force token_value =
    let secret =
      Option.value ~default:(Sihl.Configuration.read_secret ()) secret
    in
    match Jwto.decode_and_verify secret token_value, force with
    | Error msg, None ->
      Logs.warn (fun m -> m "Failed to decode and verify token: %s" msg);
      Lwt.return None
    | Ok token, Some () -> Lwt.return (Some (Jwto.get_payload token))
    | Ok token, None ->
      let%lwt is_active = is_active token_value in
      if is_active
      then Lwt.return (Some (Jwto.get_payload token))
      else Lwt.return None
    | Error msg, Some () ->
      Logs.warn (fun m -> m "Failed to decode and verify token: %s" msg);
      (match Jwto.decode token_value with
       | Error msg ->
         Logs.warn (fun m -> m "Failed to decode token: %s" msg);
         Lwt.return None
       | Ok token -> Lwt.return (Some (Jwto.get_payload token)))
  ;;

  let verify ?ctx:_ ?secret token =
    let secret =
      Option.value ~default:(Sihl.Configuration.read_secret ()) secret
    in
    match Jwto.decode_and_verify secret token with
    | Ok _ -> Lwt.return true
    | Error _ -> Lwt.return false
  ;;

  let is_expired ?ctx:_ ?secret token_value =
    let secret =
      Option.value ~default:(Sihl.Configuration.read_secret ()) secret
    in
    match Jwto.decode_and_verify secret token_value with
    | Ok token ->
      (match
         List.find_opt
           (fun (k, _) -> String.equal k "exp")
           (Jwto.get_payload token)
       with
       | Some (_, exp) ->
         let exp = exp |> int_of_string_opt |> Option.map float_of_int in
         (match Option.bind exp Ptime.of_float_s with
          | Some expiration_date ->
            let is_expired =
              Ptime.is_earlier expiration_date ~than:(Ptime_clock.now ())
            in
            Lwt.return is_expired
          | None ->
            raise
            @@ Sihl.Contract.Token.Exception
                 (Format.sprintf
                    "Invalid 'exp' claim found in token '%s'"
                    token_value))
       | None -> Lwt.return false)
    | Error msg ->
      Logs.warn (fun m -> m "Failed to decode and verify token: %s" msg);
      Lwt.return true
  ;;

  let is_valid ?ctx ?secret token =
    let%lwt is_expired = is_expired ?ctx ?secret token in
    Lwt.return (not is_expired)
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Token.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl.Container.Service.create lifecycle
  ;;
end

module MariaDb = Make (Repo.MariaDb (Sihl.Database.Migration.MariaDb))
module PostgreSql = Make (Repo.PostgreSql (Sihl.Database.Migration.PostgreSql))
module JwtInMemory = MakeJwt (Blacklist_repo.InMemory)
module JwtMariaDb = MakeJwt (Blacklist_repo.MariaDb)
module JwtPostgreSql = MakeJwt (Blacklist_repo.PostgreSql)
