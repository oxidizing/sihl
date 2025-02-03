include Sihl.Contract.User

let log_src = Logs.Src.create ("sihl.service." ^ Sihl.Contract.User.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : User_repo.Sig) : Sihl.Contract.User.Sig = struct
  let find_opt = Repo.get

  let find ?ctx user_id =
    let%lwt m_user = find_opt ?ctx user_id in
    match m_user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "User not found with id %s" user_id);
      raise (Sihl.Contract.User.Exception "User not found")
  ;;

  let find_by_email_opt = Repo.get_by_email

  let find_by_email ?ctx email =
    let%lwt user = find_by_email_opt ?ctx email in
    match user with
    | Some user -> Lwt.return user
    | None ->
      Logs.err (fun m -> m "User not found with email %s" email);
      raise (Sihl.Contract.User.Exception "User not found")
  ;;

  let search ?ctx ?(sort = `Desc) ?filter ?(limit = 50) ?(offset = 0) () =
    Repo.search ?ctx sort filter ~limit ~offset
  ;;

  let update_details ~user:_ ~email:_ ~username:_ = failwith "update()"

  let update ?ctx ?email ?username ?name ?given_name ?status user =
    let updated =
      { user with
        email = Option.value ~default:user.email email
      ; username =
          (match username with
           | Some username -> Some username
           | None -> user.username)
      ; name =
          (match name with
           | Some name -> Some name
           | None -> user.name)
      ; given_name =
          (match given_name with
           | Some given_name -> Some given_name
           | None -> user.given_name)
      ; status = Option.value ~default:user.status status
      }
    in
    let%lwt () = Repo.update ?ctx updated in
    find ?ctx user.id
  ;;

  let update_password
        ?ctx
        ?(password_policy = default_password_policy)
        user
        ~old_password
        ~new_password
        ~new_password_confirmation
    =
    match
      validate_change_password
        user
        ~old_password
        ~new_password
        ~new_password_confirmation
        ~password_policy
    with
    | Ok () ->
      let updated_user =
        match set_user_password user new_password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
            m "Can not update password of user '%s': %s" user.email msg);
          raise (Sihl.Contract.User.Exception msg)
      in
      let%lwt () = Repo.update ?ctx updated_user in
      find ?ctx user.id |> Lwt.map Result.ok
    | Error msg -> Lwt.return @@ Error msg
  ;;

  let set_password
        ?ctx
        ?(password_policy = default_password_policy)
        user
        ~password
        ~password_confirmation
    =
    let%lwt result =
      validate_new_password ~password ~password_confirmation ~password_policy
      |> Lwt.return
    in
    match result with
    | Error msg -> Lwt.return @@ Error msg
    | Ok () ->
      let%lwt result = Repo.get ?ctx user.id in
      (* Re-fetch user to make sure that we have an up-to-date model *)
      let%lwt user =
        match result with
        | Some user -> Lwt.return user
        | None -> raise (Sihl.Contract.User.Exception "Failed to create user")
      in
      let updated_user =
        match set_user_password user password with
        | Ok user -> user
        | Error msg ->
          Logs.err (fun m ->
            m "Can not set password of user %s: %s" user.email msg);
          raise (Sihl.Contract.User.Exception msg)
      in
      let%lwt () = Repo.update ?ctx updated_user in
      find ?ctx user.id |> Lwt.map Result.ok
  ;;

  let create
        ?ctx
        ?id
        ~email
        ~password
        ~username
        ~name
        ~given_name
        ~admin
        confirmed
    =
    let user =
      make ?id ~email ~password ~username ~name ~given_name ~admin confirmed
    in
    match user with
    | Ok user ->
      let%lwt () = Repo.insert ?ctx user in
      let%lwt user = find ?ctx user.id in
      Lwt.return (Ok user)
    | Error msg -> raise (Sihl.Contract.User.Exception msg)
  ;;

  let create_user ?ctx ?id ?username ?name ?given_name ~password email =
    let%lwt user =
      create
        ?ctx
        ?id
        ~password
        ~username
        ~name
        ~given_name
        ~admin:false
        ~email
        false
    in
    match user with
    | Ok user -> Lwt.return user
    | Error msg -> raise (Sihl.Contract.User.Exception msg)
  ;;

  let create_admin ?ctx ?id ?username ?name ?given_name ~password email =
    let%lwt user = Repo.get_by_email ?ctx email in
    let%lwt () =
      match user with
      | Some _ ->
        Logs.err (fun m ->
          m "Can not create admin '%s' since the email is already taken" email);
        raise (Sihl.Contract.User.Exception "Email already taken")
      | None -> Lwt.return ()
    in
    let%lwt user =
      create
        ?ctx
        ?id
        ~password
        ~username
        ~name
        ~given_name
        ~admin:true
        ~email
        true
    in
    match user with
    | Ok user -> Lwt.return user
    | Error msg ->
      Logs.err (fun m -> m "Can not create admin '%s': %s" email msg);
      raise (Sihl.Contract.User.Exception msg)
  ;;

  let register_user
        ?ctx
        ?id
        ?(password_policy = default_password_policy)
        ?username
        ?name
        ?given_name
        email
        ~password
        ~password_confirmation
    =
    match
      validate_new_password ~password ~password_confirmation ~password_policy
    with
    | Error msg -> Lwt_result.fail @@ `Invalid_password_provided msg
    | Ok () ->
      let%lwt user = find_by_email_opt ?ctx email in
      (match user with
       | None ->
         create_user ?ctx ?id ?username ?name ?given_name ~password email
         |> Lwt.map Result.ok
       | Some _ -> Lwt_result.fail `Already_registered)
  ;;

  let login ?ctx email ~password =
    let open Sihl.Contract.User in
    let%lwt user = find_by_email_opt ?ctx email in
    match user with
    | None -> Lwt_result.fail `Does_not_exist
    | Some user ->
      if matches_password password user
      then Lwt_result.return user
      else Lwt_result.fail `Incorrect_password
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let create_admin_cmd =
    Sihl.Command.make
      ~name:"user.admin"
      ~help:"<email> <password>"
      ~description:"Creates a user with admin privileges."
      (fun args ->
         match args with
         | [ email; password ] ->
           let%lwt () = start () in
           create_admin ~password email |> Lwt.map ignore |> Lwt.map Option.some
         | _ -> Lwt.return None)
  ;;

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.User.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register ?(commands = [ create_admin_cmd ]) () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl.Container.Service.create ~commands lifecycle
  ;;

  module Web = struct
    let user_from_session = Web.user_from_session find_opt
    let user_from_token = Web.user_from_token find_opt
  end
end

module PostgreSql =
  Make (User_repo.MakePostgreSql (Sihl.Database.Migration.PostgreSql))

module MariaDb = Make (User_repo.MakeMariaDb (Sihl.Database.Migration.MariaDb))

module Password_reset = struct
  let log_src = Password_reset.log_src

  module MakePostgreSql (TokenService : Sihl.Contract.Token.Sig) =
    Password_reset.Make (PostgreSql) (TokenService)

  module MakeMariaDb (TokenService : Sihl.Contract.Token.Sig) =
    Password_reset.Make (MariaDb) (TokenService)
end
