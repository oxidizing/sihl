open Lwt.Syntax
module Core = Sihl_core
module User = Model

let log_src = Logs.Src.create "sihl.service.user"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

module Make (Repo : Sig.REPOSITORY) : Sig.SERVICE = struct
  let find_opt ~user_id = Repo.get ~id:user_id

  let find ~user_id =
    let* m_user = find_opt ~user_id in
    match m_user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "USER: User not found with id %s" user_id);
      raise (Exception "User not found")
  ;;

  let find_by_email_opt ~email =
    (* TODO add support for lowercase UTF-8
     * String.lowercase only supports US-ASCII, but
     * email addresses can contain other letters
     * (https://tools.ietf.org/html/rfc6531) like umlauts.
     *)
    Repo.get_by_email ~email:(String.lowercase_ascii email)
  ;;

  let find_by_email ~email =
    let* user = find_by_email_opt ~email in
    match user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "USER: User not found with email %s" email);
      raise (Exception "User not found")
  ;;

  let find_all ~query = Repo.get_all ~query

  let update_password
      ?(password_policy = User.default_password_policy)
      ~user
      ~old_password
      ~new_password
      ~new_password_confirmation
      ()
    =
    match
      User.validate_change_password
        user
        ~old_password
        ~new_password
        ~new_password_confirmation
        ~password_policy
    with
    | Ok () ->
      let updated_user =
        match User.set_user_password user new_password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
              m "USER: Can not update password of user %s: %s" (User.email user) msg);
          raise (Exception msg)
      in
      let* () = Repo.update ~user:updated_user in
      Lwt.return @@ Ok updated_user
    | Error msg -> Lwt.return @@ Error msg
  ;;

  let update_details ~user ~email ~username =
    let updated_user = User.set_user_details user ~email ~username in
    let* () = Repo.update ~user:updated_user in
    find ~user_id:(User.id user)
  ;;

  let set_password
      ?(password_policy = User.default_password_policy)
      ~user
      ~password
      ~password_confirmation
      ()
    =
    let* result =
      User.validate_new_password ~password ~password_confirmation ~password_policy
      |> Lwt.return
    in
    match result with
    | Error msg -> Lwt.return @@ Error msg
    | Ok () ->
      let updated_user =
        match User.set_user_password user password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
              m "USER: Can not set password of user %s: %s" (User.email user) msg);
          raise (Exception msg)
      in
      let* () = Repo.update ~user:updated_user in
      Lwt_result.return updated_user
  ;;

  let create_user ~email ~password ~username =
    let user =
      match User.create ~email ~password ~username ~admin:false ~confirmed:false with
      | Ok user -> user
      | Error msg -> raise (Exception msg)
    in
    let* () = Repo.insert ~user in
    Lwt.return user
  ;;

  let create_admin ~email ~password ~username =
    let* user = Repo.get_by_email ~email in
    let* () =
      match user with
      | Some _ ->
        Logs.err (fun m ->
            m "USER: Can not create admin %s since the email is already taken" email);
        raise (Exception "Email already taken")
      | None -> Lwt.return ()
    in
    let user =
      match User.create ~email ~password ~username ~admin:true ~confirmed:true with
      | Ok user -> user
      | Error msg ->
        Logs.err (fun m -> m "USER: Can not create admin %s %s" email msg);
        raise (Exception msg)
    in
    let* () = Repo.insert ~user in
    Lwt.return user
  ;;

  let register_user
      ?(password_policy = User.default_password_policy)
      ?username
      ~email
      ~password
      ~password_confirmation
      ()
    =
    match
      User.validate_new_password ~password ~password_confirmation ~password_policy
    with
    | Error msg -> Lwt_result.fail @@ Model.Error.InvalidPasswordProvided msg
    | Ok () ->
      let* user = find_by_email_opt ~email in
      (match user with
      | None -> create_user ~username ~email ~password |> Lwt.map Result.ok
      | Some _ -> Lwt_result.fail Model.Error.AlreadyRegistered)
  ;;

  let login ~email ~password =
    let* user = find_by_email_opt ~email in
    match user with
    | None -> Lwt_result.fail Model.Error.DoesNotExist
    | Some user ->
      if User.matches_password password user
      then Lwt_result.return user
      else Lwt_result.fail Model.Error.IncorrectPassword
  ;;

  let create_admin_cmd =
    Core.Command.make
      ~name:"createadmin"
      ~help:"<username> <email> <password>"
      ~description:"Create an admin user"
      (fun args ->
        match args with
        | [ username; email; password ] ->
          create_admin ~email ~password ~username:(Some username) |> Lwt.map ignore
        | _ -> raise (Core.Command.Exception "Usage: <username> <email> <password>"))
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create "user" ~dependencies:Repo.lifecycles ~start ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Core.Container.Service.create ~commands:[ create_admin_cmd ] lifecycle
  ;;
end
