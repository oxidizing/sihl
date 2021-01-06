let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.User.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : User_repo.Sig) : Sihl_contract.User.Sig = struct
  let find_opt ~user_id = Repo.get ~id:user_id

  let find ~user_id =
    let open Lwt.Syntax in
    let* m_user = find_opt ~user_id in
    match m_user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "User not found with id %s" user_id);
      raise (Sihl_contract.User.Exception "User not found")
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
    let open Lwt.Syntax in
    let* user = find_by_email_opt ~email in
    match user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "User not found with email %s" email);
      raise (Sihl_contract.User.Exception "User not found")
  ;;

  let search ?(sort = `Desc) ?filter limit = Repo.search sort filter limit

  let update_password
      ?(password_policy = Sihl_facade.User.default_password_policy)
      ~user
      ~old_password
      ~new_password
      ~new_password_confirmation
      ()
    =
    let open Lwt.Syntax in
    match
      Sihl_facade.User.validate_change_password
        user
        ~old_password
        ~new_password
        ~new_password_confirmation
        ~password_policy
    with
    | Ok () ->
      let updated_user =
        match Sihl_facade.User.set_user_password user new_password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
              m "Can not update password of user %s: %s" user.email msg);
          raise (Sihl_contract.User.Exception msg)
      in
      let* () = Repo.update ~user:updated_user in
      Lwt.return @@ Ok updated_user
    | Error msg -> Lwt.return @@ Error msg
  ;;

  let update_details ~user ~email ~username =
    let open Lwt.Syntax in
    let updated_user =
      Sihl_facade.User.set_user_details user ~email ~username
    in
    let* () = Repo.update ~user:updated_user in
    find ~user_id:user.id
  ;;

  let set_password
      ?(password_policy = Sihl_facade.User.default_password_policy)
      ~user
      ~password
      ~password_confirmation
      ()
    =
    let open Lwt.Syntax in
    let* result =
      Sihl_facade.User.validate_new_password
        ~password
        ~password_confirmation
        ~password_policy
      |> Lwt.return
    in
    match result with
    | Error msg -> Lwt.return @@ Error msg
    | Ok () ->
      let updated_user =
        match Sihl_facade.User.set_user_password user password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
              m "USER: Can not set password of user %s: %s" user.email msg);
          raise (Sihl_contract.User.Exception msg)
      in
      let* () = Repo.update ~user:updated_user in
      Lwt_result.return updated_user
  ;;

  let create ~email ~password ~username ~admin ~confirmed =
    let open Lwt.Syntax in
    let user =
      Sihl_facade.User.make ~email ~password ~username ~admin ~confirmed
    in
    match user with
    | Ok user ->
      let* () = Repo.insert ~user in
      Lwt.return (Ok user)
    | Error msg -> raise (Sihl_contract.User.Exception msg)
  ;;

  let create_user ~email ~password ~username =
    let open Lwt.Syntax in
    let* user =
      Sihl_facade.User.create
        ~email
        ~password
        ~username
        ~admin:false
        ~confirmed:false
    in
    let user =
      match user with
      | Ok user -> user
      | Error msg -> raise (Sihl_contract.User.Exception msg)
    in
    Lwt.return user
  ;;

  let create_admin ~email ~password ~username =
    let open Lwt.Syntax in
    let* user = Repo.get_by_email ~email in
    let* () =
      match user with
      | Some _ ->
        Logs.err (fun m ->
            m "Can not create admin %s since the email is already taken" email);
        raise (Sihl_contract.User.Exception "Email already taken")
      | None -> Lwt.return ()
    in
    let* user =
      Sihl_facade.User.create
        ~email
        ~password
        ~username
        ~admin:true
        ~confirmed:true
    in
    let user =
      match user with
      | Ok user -> user
      | Error msg ->
        Logs.err (fun m -> m "Can not create admin %s %s" email msg);
        raise (Sihl_contract.User.Exception msg)
    in
    Lwt.return user
  ;;

  let register_user
      ?(password_policy = Sihl_facade.User.default_password_policy)
      ?username
      ~email
      ~password
      ~password_confirmation
      ()
    =
    let open Lwt.Syntax in
    let open Sihl_contract.User in
    match
      Sihl_facade.User.validate_new_password
        ~password
        ~password_confirmation
        ~password_policy
    with
    | Error msg -> Lwt_result.fail @@ InvalidPasswordProvided msg
    | Ok () ->
      let* user = find_by_email_opt ~email in
      (match user with
      | None -> create_user ~username ~email ~password |> Lwt.map Result.ok
      | Some _ -> Lwt_result.fail AlreadyRegistered)
  ;;

  let login ~email ~password =
    let open Lwt.Syntax in
    let open Sihl_contract.User in
    let* user = find_by_email_opt ~email in
    match user with
    | None -> Lwt_result.fail DoesNotExist
    | Some user ->
      if Sihl_facade.User.matches_password password user
      then Lwt_result.return user
      else Lwt_result.fail IncorrectPassword
  ;;

  let create_admin_cmd =
    Sihl_core.Command.make
      ~name:"createadmin"
      ~help:"<username> <email> <password>"
      ~description:"Create an admin user"
      (fun args ->
        match args with
        | [ username; email; password ] ->
          create_admin ~email ~password ~username:(Some username)
          |> Lwt.map ignore
        | _ ->
          raise
            (Sihl_core.Command.Exception "Usage: <username> <email> <password>"))
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      Sihl_contract.User.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl_core.Container.Service.create ~commands:[ create_admin_cmd ] lifecycle
  ;;
end

module PostgreSql =
  Make (User_repo.MakePostgreSql (Sihl_persistence.Migration.PostgreSql))

module MariaDb = Make (User_repo.MakeMariaDb (Sihl_persistence.Migration.MariaDb))
