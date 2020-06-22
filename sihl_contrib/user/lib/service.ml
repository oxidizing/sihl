open Base

let ( let* ) = Lwt_result.bind

module Make (UserRepo : Repo.REPOSITORY) : Sihl.User.Sig.SERVICE = struct
  let on_bind req =
    let* () = Sihl.Migration.register req (UserRepo.migrate ()) in
    Sihl.Repo.register_cleaner req UserRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get request ~user_id =
    UserRepo.User.get ~id:user_id |> Sihl.Core.Db.query_db request

  let get_by_email request ~email =
    UserRepo.User.get_by_email ~email |> Sihl.Core.Db.query_db request

  let get_all request = UserRepo.User.get_all |> Sihl.Core.Db.query_db request

  let update_password request ~email ~old_password ~new_password =
    let* user =
      get_by_email request ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update password")
    in
    let* () =
      Sihl.User.validate user ~old_password ~new_password |> Lwt.return
    in
    let updated_user = Sihl.User.set_user_password user new_password in
    let* () =
      UserRepo.User.update updated_user |> Sihl.Core.Db.query_db request
    in
    Lwt.return @@ Ok updated_user

  let update_details request ~email ~username =
    let* user =
      get_by_email request ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update details")
    in
    let updated_user = Sihl.User.set_user_details user ~email ~username in
    let* () =
      UserRepo.User.update updated_user |> Sihl.Core.Db.query_db request
    in
    Lwt.return @@ Ok updated_user

  let set_password request ~user_id ~password =
    let* user =
      get request ~user_id
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to set password")
    in
    let* () = Sihl.User.validate_password password |> Lwt.return in
    let updated_user = Sihl.User.set_user_password user password in
    let* () =
      UserRepo.User.update updated_user |> Sihl.Core.Db.query_db request
    in
    Lwt.return @@ Ok updated_user

  (* TODO refactor below to token service and use cases *)

  let is_valid_auth_token request token =
    let* token =
      UserRepo.Token.get ~value:token |> Sihl.Core.Db.query_db request
    in
    token
    |> Option.value_map ~default:false ~f:Sihl.User.Token.is_valid_auth
    |> Result.return |> Lwt.return

  let get_by_token request token =
    let* token =
      UserRepo.Token.get ~value:token
      |> Sihl.Core.Db.query_db request
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found")
    in
    let token_user = token |> Sihl.User.Token.user in
    get request ~user_id:token_user

  let send_registration_email request user =
    let token = Sihl.User.Token.create_email_confirmation user in
    let* () = UserRepo.Token.insert token |> Sihl.Core.Db.query_db request in
    let email = Model.Email.create_confirmation token user in
    Sihl.Email.send request email

  let register ?(suppress_email = false) request ~email ~password ~username =
    let* user = get_by_email request ~email in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      Sihl.User.create ~email ~password ~username ~admin:false ~confirmed:false
    in
    let* () = UserRepo.User.insert user |> Sihl.Core.Db.query_db request in
    let* () =
      if suppress_email then Lwt.return @@ Ok ()
      else send_registration_email request user
    in
    Lwt.return @@ Ok user

  let create_admin request ~email ~password ~username =
    let* user =
      UserRepo.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      Sihl.User.create ~email ~password ~username ~admin:true ~confirmed:true
    in
    let* () = UserRepo.User.insert user |> Sihl.Core.Db.query_db request in
    Lwt.return @@ Ok user

  let logout request user =
    let* () = Sihl.Session.remove_value ~key:"users.id" request in
    let id = Sihl.User.id user in
    UserRepo.Token.delete_by_user ~id |> Sihl.Core.Db.query_db request

  let login request ~email ~password =
    let* user =
      get_by_email request ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"Invalid user provided")
    in
    if Sihl.User.matches_password password user then
      let token = Sihl.User.Token.create user in
      let* () = UserRepo.Token.insert token |> Sihl.Core.Db.query_db request in
      Lwt.return @@ Ok token
    else Lwt.return @@ Error "Wrong credentials provided"

  let authenticate_credentials request ~email ~password =
    let* user =
      get_by_email request ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"Invalid user provided")
    in
    if Sihl.User.matches_password password user then Lwt.return @@ Ok user
    else Lwt.return @@ Error "Wrong credentials provided"

  let token request user =
    let token = Sihl.User.Token.create user in
    let* () = UserRepo.Token.insert token |> Sihl.Core.Db.query_db request in
    Lwt.return @@ Ok token

  (* TODO move to use case layer *)

  (* let confirm_email request token =
   *   let* token =
   *     UserRepo.Token.get ~value:token |> Sihl.Core.Db.query_db request
   *   in
   *   let token =
   *     token |> Sihl.Core.Err.with_bad_request "invalid token provided"
   *   in
   *   if not @@ Sihl.User.Token.is_valid_email_configuration token then
   *     Sihl.Core.Err.raise_bad_request "invalid confirmation token provided"
   *   else
   *     Sihl.Core.Db.query_db_with_trx_exn request (fun connection ->
   *         let* () =
   *           UserRepo.Token.update (Sihl.User.Token.inactivate token) connection
   *           |> Sihl.Core.Err.database
   *         in
   *         let* user =
   *           UserRepo.User.get ~id:token.user connection
   *           |> Sihl.Core.Err.database
   *         in
   *         UserRepo.User.update (Sihl.User.confirm user) connection)
   *
   * let request_password_reset request ~email =
   *   let* user = get_by_email request ~email in
   *   let token = Sihl.User.Token.create_password_reset user in
   *   let* () =
   *     UserRepo.Token.insert token |> Sihl.Core.Db.query_db_exn request
   *   in
   *   let email = Model.Email.create_password_reset token user in
   *   let* result = Sihl.Email.send request email in
   *   result |> Sihl.Core.Err.with_email |> Lwt.return
   *
   * let reset_password request ~token ~new_password =
   *   let* token =
   *     UserRepo.Token.get ~value:token |> Sihl.Core.Db.query_db request
   *   in
   *   let token =
   *     token |> Sihl.Core.Err.with_bad_request "invalid token provided"
   *   in
   *   if not @@ Sihl.User.Token.can_reset_password token then
   *     Sihl.Core.Err.raise_bad_request "invalid or inactive token provided"
   *   else
   *     let* user =
   *       UserRepo.User.get ~id:token.user |> Sihl.Core.Db.query_db request
   *     in
   *     let user =
   *       user |> Sihl.Core.Err.with_bad_request "invalid user for token found"
   *     in
   *     (\* TODO use transaction here *\)
   *     let updated_user = Sihl.User.update_password user new_password in
   *     let* () =
   *       UserRepo.User.update updated_user |> Sihl.Core.Db.query_db_exn request
   *     in
   *     let token = Sihl.User.Token.inactivate token in
   *     UserRepo.Token.update token |> Sihl.Core.Db.query_db_exn request *)
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
