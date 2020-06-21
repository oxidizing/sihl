open Base

let ( let* ) = Lwt.bind

module Make (Repo : Repo.REPOSITORY) : Sihl.User.Sig.SERVICE = struct
  let on_bind req = Sihl.Migration.register req (Repo.migrate ())

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let is_valid_auth_token request token =
    let* token = Repo.Token.get ~value:token |> Sihl.Core.Db.query_db request in
    token |> Result.ok
    |> Option.value_map ~default:false ~f:Sihl.User.Token.is_valid_auth
    |> Lwt.return

  let get request user ~user_id =
    if Sihl.User.is_admin user || Sihl.User.is_owner user user_id then
      let* user = Repo.User.get ~id:user_id |> Sihl.Core.Db.query_db request in
      user
      |> Sihl.Core.Err.with_bad_request
           ("could not find user with id " ^ user_id)
      |> Lwt.return
    else Sihl.Core.Err.raise_no_permissions "user is not allowed to fetch user"

  let get_by_token request token =
    let* token = Repo.Token.get ~value:token |> Sihl.Core.Db.query_db request in
    let token_user =
      token |> Sihl.Core.Err.with_not_authenticated |> Sihl.User.Token.user
    in
    Repo.User.get ~id:token_user
    |> Sihl.Core.Db.query_db request
    |> Lwt.map Sihl.Core.Err.with_not_authenticated

  let get_all request user =
    if Sihl.User.is_admin user then
      Repo.User.get_all |> Sihl.Core.Db.query_db_exn request
    else
      Sihl.Core.Err.raise_no_permissions
        "user is not allowed to fetch all users"

  let get_by_email request ~email =
    Repo.User.get_by_email ~email |> Sihl.Core.Db.query_db_exn request

  let send_registration_email request user =
    let token = Sihl.User.Token.create_email_confirmation user in
    let* () = Repo.Token.insert token |> Sihl.Core.Db.query_db_exn request in
    let email = Model.Email.create_confirmation token user in
    let* result = Sihl.Email.send request email in
    result |> Sihl.Core.Err.with_email |> Lwt.return

  let register ?(suppress_email = false) request ~email ~password ~username =
    let* user =
      Repo.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    if Result.is_ok user then
      Sihl.Core.Err.raise_bad_request "email already taken"
    else
      let user =
        Sihl.User.create ~email ~password ~username ~admin:false
          ~confirmed:false
      in
      let* () = Repo.User.insert user |> Sihl.Core.Db.query_db_exn request in
      let* () =
        if suppress_email then Lwt.return ()
        else send_registration_email request user
      in
      Lwt.return user

  let create_admin request ~email ~password ~username =
    let* user =
      Repo.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    if Result.is_ok user then
      Sihl.Core.Err.raise_bad_request "email already taken"
    else
      let user =
        Sihl.User.create ~email ~password ~username ~admin:true ~confirmed:true
      in
      let* () = Repo.User.insert user |> Sihl.Core.Db.query_db_exn request in
      Lwt.return user

  let logout request user =
    let* () =
      Sihl.Session.remove_value ~key:"users.id" request
      |> Lwt_result.map_err Sihl.Core.Err.raise_server
      |> Lwt.map Result.ok_exn
    in
    let id = Sihl.User.id user in
    Repo.Token.delete_by_user ~id |> Sihl.Core.Db.query_db_exn request

  let login request ~email ~password =
    let* user =
      Repo.User.get_by_email ~email |> Sihl.Core.Db.query_db_exn request
    in
    if Sihl.User.matches_password password user then
      let token = Sihl.User.Token.create user in
      let* () = Repo.Token.insert token |> Sihl.Core.Db.query_db_exn request in
      Lwt.return token
    else Sihl.Core.Err.raise_not_authenticated "wrong credentials provided"

  let authenticate_credentials request ~email ~password =
    let* user = get_by_email request ~email in
    if Sihl.User.matches_password password user then Lwt.return user
    else Sihl.Core.Err.raise_not_authenticated @@ "wrong credentials provided"

  let token request user =
    let token = Sihl.User.Token.create user in
    let* result = Repo.Token.insert token |> Sihl.Core.Db.query_db request in
    let () = result |> Sihl.Core.Err.with_database "failed to store token" in
    Lwt.return token

  let update_password request current_user ~email ~old_password ~new_password =
    let* user = get_by_email request ~email in
    let _ =
      Sihl.User.validate user ~old_password ~new_password
      |> Sihl.Core.Err.with_bad_request
           "invalid password provided TODO: make this msg optional"
    in
    if
      Sihl.User.is_admin current_user
      || Sihl.User.is_owner current_user (Sihl.User.id user)
    then
      let updated_user = Sihl.User.update_password user new_password in
      let* () =
        Repo.User.update updated_user |> Sihl.Core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl.Core.Err.raise_no_permissions
        "user is not allowed to update this user"

  let update_details request current_user ~email ~username =
    let* user = get_by_email request ~email in
    if
      Sihl.User.is_admin current_user
      || Sihl.User.is_owner current_user (Sihl.User.id user)
    then
      let updated_user = Sihl.User.update_details user ~email ~username in
      let* () =
        Repo.User.update updated_user |> Sihl.Core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl.Core.Err.raise_no_permissions
        "user is not allowed to update this user"

  let set_password request current_user ~user_id ~password =
    let* user = Repo.User.get ~id:user_id |> Sihl.Core.Db.query_db request in
    let user =
      user |> Sihl.Core.Err.with_bad_request "user to set password not found"
    in
    let _ =
      Sihl.User.validate_password password
      |> Sihl.Core.Err.with_bad_request
           "invalid password provided TODO: make this msg optional"
    in
    if Sihl.User.is_admin current_user then
      let updated_user = Sihl.User.update_password user password in
      let* () =
        Repo.User.update updated_user |> Sihl.Core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl.Core.Err.raise_no_permissions "user is not allowed to set password"

  let confirm_email request token =
    let* token = Repo.Token.get ~value:token |> Sihl.Core.Db.query_db request in
    let token =
      token |> Sihl.Core.Err.with_bad_request "invalid token provided"
    in
    if not @@ Sihl.User.Token.is_valid_email_configuration token then
      Sihl.Core.Err.raise_bad_request "invalid confirmation token provided"
    else
      Sihl.Core.Db.query_db_with_trx_exn request (fun connection ->
          let* () =
            Repo.Token.update (Sihl.User.Token.inactivate token) connection
            |> Sihl.Core.Err.database
          in
          let* user =
            Repo.User.get ~id:token.user connection |> Sihl.Core.Err.database
          in
          Repo.User.update (Sihl.User.confirm user) connection)

  let request_password_reset request ~email =
    let* user = get_by_email request ~email in
    let token = Sihl.User.Token.create_password_reset user in
    let* () = Repo.Token.insert token |> Sihl.Core.Db.query_db_exn request in
    let email = Model.Email.create_password_reset token user in
    let* result = Sihl.Email.send request email in
    result |> Sihl.Core.Err.with_email |> Lwt.return

  let reset_password request ~token ~new_password =
    let* token = Repo.Token.get ~value:token |> Sihl.Core.Db.query_db request in
    let token =
      token |> Sihl.Core.Err.with_bad_request "invalid token provided"
    in
    if not @@ Sihl.User.Token.can_reset_password token then
      Sihl.Core.Err.raise_bad_request "invalid or inactive token provided"
    else
      let* user =
        Repo.User.get ~id:token.user |> Sihl.Core.Db.query_db request
      in
      let user =
        user |> Sihl.Core.Err.with_bad_request "invalid user for token found"
      in
      (* TODO use transaction here *)
      let updated_user = Sihl.User.update_password user new_password in
      let* () =
        Repo.User.update updated_user |> Sihl.Core.Db.query_db_exn request
      in
      let token = Sihl.User.Token.inactivate token in
      Repo.Token.update token |> Sihl.Core.Db.query_db_exn request
end

module UserMariaDb = Make (Repo.MariaDb)

let mariadb =
  Sihl.Container.create_binding Sihl.User.Sig.key
    (module UserMariaDb)
    (module UserMariaDb)

module UserPostgreSql = Make (Repo.PostgreSql)

let postgresql =
  Sihl.Container.create_binding Sihl.User.Sig.key
    (module UserPostgreSql)
    (module UserPostgreSql)
