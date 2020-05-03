open Base

let ( let* ) = Lwt.bind

module User = struct
  let authenticate request =
    request |> Middleware.Authentication.user |> Result.of_option ~error:""
    |> Sihl_core.Fail.with_no_permission
         "no user found, have you applied the authentication middleware?"

  let send_registration_email request user =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in
    let token = Model.Token.create_email_confirmation user in
    let* () =
      Repository.Token.insert token |> Sihl_core.Db.query_db_exn request
    in
    let email = Model.Email.Confirmation.create token user in
    Sihl_core.Email.send_exn email

  let register ?(suppress_email = false) request ~email ~password ~username =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db request
    in
    if Result.is_ok user then
      Sihl_core.Fail.raise_bad_request "email already taken"
    else
      let user =
        Model.User.create ~email ~password ~username ~admin:false
          ~confirmed:false
      in
      let* () =
        Repository.User.insert user |> Sihl_core.Db.query_db_exn request
      in
      let* () =
        if suppress_email then Lwt.return ()
        else send_registration_email request user
      in
      Lwt.return user

  let create_admin request ~email ~password ~username =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db request
    in
    if Result.is_ok user then
      Sihl_core.Fail.raise_bad_request "email already taken"
    else
      let user =
        Model.User.create ~email ~password ~username ~admin:true ~confirmed:true
      in
      let* () =
        Repository.User.insert user |> Sihl_core.Db.query_db_exn request
      in
      Lwt.return user

  let logout request user =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let id = Model.User.id user in
    Repository.Token.delete_by_user ~id |> Sihl_core.Db.query_db_exn request

  let login request ~email ~password =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db_exn request
    in
    if Model.User.matches_password password user then
      let token = Model.Token.create user in
      let* () =
        Repository.Token.insert token |> Sihl_core.Db.query_db_exn request
      in
      Lwt.return token
    else Sihl_core.Fail.raise_not_authenticated "wrong credentials provided"

  let token request user =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let token = Model.Token.create user in
    let* result =
      Repository.Token.insert token |> Sihl_core.Db.query_db request
    in
    let () = result |> Sihl_core.Fail.with_database "failed to store token" in
    Lwt.return token

  let get request user ~user_id =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    if Model.User.is_admin user || Model.User.is_owner user user_id then
      let* user =
        Repository.User.get ~id:user_id |> Sihl_core.Db.query_db request
      in
      user
      |> Sihl_core.Fail.with_bad_request
           ("could not find user with id " ^ user_id)
      |> Lwt.return
    else Sihl_core.Fail.raise_no_permissions "user is not allowed to fetch user"

  let get_all request user =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    if Model.User.is_admin user then
      Repository.User.get_all |> Sihl_core.Db.query_db_exn request
    else
      Sihl_core.Fail.raise_no_permissions
        "user is not allowed to fetch all users"

  let update_password request current_user ~email ~old_password ~new_password =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db_exn request
    in
    let _ =
      Model.User.is_valid user ~old_password ~new_password
      |> Sihl_core.Fail.with_bad_request
           "invalid password provided TODO: make this msg optional"
    in
    if
      Model.User.is_admin current_user
      || Model.User.is_owner current_user user.id
    then
      let updated_user = Model.User.update_password user new_password in
      let* () =
        Repository.User.update updated_user |> Sihl_core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl_core.Fail.raise_no_permissions
        "user is not allowed to update this user"

  let update_details request current_user ~email ~username =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db_exn request
    in
    if
      Model.User.is_admin current_user
      || Model.User.is_owner current_user user.id
    then
      let updated_user = Model.User.update_details user ~email ~username in
      let* () =
        Repository.User.update updated_user |> Sihl_core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl_core.Fail.raise_no_permissions
        "user is not allowed to update this user"

  let set_password request current_user ~user_id ~password =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get ~id:user_id |> Sihl_core.Db.query_db request
    in
    let user =
      user |> Sihl_core.Fail.with_bad_request "user to set password not found"
    in
    let _ =
      Model.User.validate_password password
      |> Sihl_core.Fail.with_bad_request
           "invalid password provided TODO: make this msg optional"
    in
    if Model.User.is_admin current_user then
      let updated_user = Model.User.update_password user password in
      let* () =
        Repository.User.update updated_user |> Sihl_core.Db.query_db_exn request
      in
      Lwt.return updated_user
    else
      Sihl_core.Fail.raise_no_permissions "user is not allowed to set password"

  let confirm_email request token =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* token =
      Repository.Token.get ~value:token |> Sihl_core.Db.query_db request
    in
    let token =
      token |> Sihl_core.Fail.with_bad_request "invalid token provided"
    in
    if not @@ Model.Token.is_valid_email_configuration token then
      Sihl_core.Fail.raise_bad_request "invalid confirmation token provided"
    else
      Sihl_core.Db.query_db_with_trx_exn request (fun connection ->
          let* () =
            Repository.Token.update (Model.Token.inactivate token)
            |> Sihl_core.Db.query_db_exn request
          in
          let* user =
            Repository.User.get ~id:token.user |> Sihl_core.Db.query_db request
          in
          let user =
            user |> Sihl_core.Fail.with_bad_request "invalid token provided"
          in
          Repository.User.update (Model.User.confirm user) connection)

  let request_password_reset request ~email =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl_core.Db.query_db request
    in
    let user =
      user |> Sihl_core.Fail.with_bad_request "invalid email provided"
    in
    let token = Model.Token.create_password_reset user in
    let* () =
      Repository.Token.insert token |> Sihl_core.Db.query_db_exn request
    in
    let email = Model.Email.PasswordReset.create token user in
    Sihl_core.Email.send email

  let reset_password request ~token ~new_password =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let* token =
      Repository.Token.get ~value:token |> Sihl_core.Db.query_db request
    in
    let token =
      token |> Sihl_core.Fail.with_bad_request "invalid token provided"
    in
    if not @@ Model.Token.can_reset_password token then
      Sihl_core.Fail.raise_bad_request "invalid or inactive token provided"
    else
      let* user =
        Repository.User.get ~id:token.user |> Sihl_core.Db.query_db request
      in
      let user =
        user |> Sihl_core.Fail.with_bad_request "invalid user for token found"
      in
      (* TODO use transaction here *)
      let updated_user = Model.User.update_password user new_password in
      let* () =
        Repository.User.update updated_user |> Sihl_core.Db.query_db_exn request
      in
      let token = Model.Token.inactivate token in
      Repository.Token.update token |> Sihl_core.Db.query_db_exn request
end
