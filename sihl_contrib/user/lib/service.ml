open Base

let ( let* ) = Lwt_result.bind

module User = struct
  let is_valid_auth_token request token =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* token =
      Repository.Token.get ~value:token |> Sihl.Core.Db.query_db request
    in
    token |> Model.Token.is_valid_auth |> Result.return |> Lwt.return

  let get request user ~user_id =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    if Sihl.User.is_admin user || Sihl.User.is_owner user user_id then
      let* user =
        Repository.User.get ~id:user_id
        |> Sihl.Core.Db.query_db request
        |> Lwt_result.map_err (fun _ ->
               Sihl.Error.bad_request
                 ~msg:("Could not find user with id " ^ user_id)
                 ())
      in
      user |> Result.return |> Lwt.return
    else
      Sihl.Error.authorization ~msg:"User is not allowed to fetch user" ()
      |> Result.fail |> Lwt.return

  let get_by_token request token =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* token =
      Repository.Token.get ~value:token
      |> Sihl.Core.Db.query_db request
      |> Lwt_result.map_err Sihl.Error.authentication
    in
    let token_user = token |> Model.Token.user in
    Repository.User.get ~id:token_user
    |> Sihl.Core.Db.query_db request
    |> Lwt_result.map_err Sihl.Error.authentication

  let get_all request user =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    if Sihl.User.is_admin user then
      Repository.User.get_all |> Sihl.Core.Db.query_db request
    else
      Sihl.Error.authorization ~msg:"Not allowed to fetch all users" ()
      |> Result.fail |> Lwt.return

  let get_by_email request ~email =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in
    Repository.User.get_by_email ~email |> Sihl.Core.Db.query_db request

  let send_registration_email request user =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in
    let token = Model.Token.create_email_confirmation user in
    let* () = Repository.Token.insert token |> Sihl.Core.Db.query_db request in
    let email = Model.Email.create_confirmation token user in
    Sihl_email.Service.send request email

  let register ?(suppress_email = false) request ~email ~password ~username =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    match user with
    | None ->
        Lwt.return
        @@ Error (Sihl.Error.bad_request ~msg:"Email already taken" ())
    | Some _ ->
        let user =
          Sihl.User.create ~email ~password ~username ~admin:false
            ~confirmed:false
        in
        let* () =
          Repository.User.insert user |> Sihl.Core.Db.query_db request
        in
        let* () =
          if suppress_email then Lwt.return @@ Ok ()
          else send_registration_email request user
        in
        Lwt.return @@ Ok user

  let create_admin request ~email ~password ~username =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    match user with
    | None ->
        Lwt.return
        @@ Error (Sihl.Error.bad_request ~msg:"Email already taken" ())
    | Some _ ->
        let user =
          Sihl.User.create ~email ~password ~username ~admin:true
            ~confirmed:true
        in
        let* () =
          Repository.User.insert user |> Sihl.Core.Db.query_db request
        in
        Lwt.return @@ Ok user

  let logout request user =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in
    let* () = Sihl.Http.Session.remove ~key:"users.id" request in
    let id = Sihl.User.id user in
    Repository.Token.delete_by_user ~id |> Sihl.Core.Db.query_db request

  let login request ~email ~password =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user =
      Repository.User.get_by_email ~email |> Sihl.Core.Db.query_db request
    in
    match user with
    | Some user ->
        if Sihl.User.matches_password password user then
          let token = Model.Token.create user in
          let* () =
            Repository.Token.insert token |> Sihl.Core.Db.query_db request
          in
          Lwt.return @@ Ok token
        else Sihl.Core.Err.raise_not_authenticated "wrong credentials provided"
    | None ->
        Lwt.return @@ Error (Sihl.Error.not_found ~msg:"User not found" ())

  let authenticate_credentials request ~email ~password =
    let* user = get_by_email request ~email in
    match user with
    | Some user ->
        if Sihl.User.matches_password password user then Lwt.return @@ Ok user
        else
          Lwt.return
          @@ Error (Sihl.Error.authentication "Wrong credentials provided")
    | None ->
        Lwt.return @@ Error (Sihl.Error.not_found ~msg:"User not found" ())

  let token request user =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let token = Model.Token.create user in
    let* () = Repository.Token.insert token |> Sihl.Core.Db.query_db request in
    Lwt.return @@ Ok token

  let update_password request current_user ~email ~old_password ~new_password =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user = get_by_email request ~email in
    match user with
    | None ->
        Lwt.return @@ Error (Sihl.Error.not_found ~msg:"User not found" ())
    | Some user ->
        let* () =
          Sihl.User.validate user ~old_password ~new_password
          |> Result.map_error ~f:(fun _ ->
                 Sihl.Error.bad_request ~msg:"Invalid password provided" ())
          |> Lwt.return
        in
        if
          Sihl.User.is_admin current_user
          || Sihl.User.is_owner current_user (Sihl.User.id user)
        then
          let updated_user = Sihl.User.update_password user new_password in
          let* () =
            Repository.User.update updated_user |> Sihl.Core.Db.query_db request
          in
          Lwt.return @@ Ok updated_user
        else
          Error (Sihl.Error.authorization ~msg:"User is not allowed" ())
          |> Lwt.return

  let update_details request current_user ~email ~username =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user = get_by_email request ~email in
    match user with
    | None ->
        Lwt.return @@ Error (Sihl.Error.not_found ~msg:"User not found" ())
    | Some user ->
        if
          Sihl.User.is_admin current_user
          || Sihl.User.is_owner current_user (Sihl.User.id user)
        then
          let updated_user = Sihl.User.update_details user ~email ~username in
          let* () =
            Repository.User.update updated_user |> Sihl.Core.Db.query_db request
          in
          Lwt.return @@ Ok updated_user
        else
          Lwt.return
          @@ Error
               (Sihl.Error.authorization
                  ~msg:"User is not allowed to update this user" ())

  let set_password request current_user ~user_id ~password =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user =
      Repository.User.get ~id:user_id |> Sihl.Core.Db.query_db request
    in
    let* () =
      Sihl.User.validate_password password
      |> Result.map_error ~f:(fun _ ->
             Sihl.Error.bad_request ~msg:"Invalid password provided" ())
      |> Lwt.return
    in
    if Sihl.User.is_admin current_user then
      let updated_user = Sihl.User.update_password user password in
      let* () =
        Repository.User.update updated_user |> Sihl.Core.Db.query_db request
      in
      Lwt.return @@ Ok updated_user
    else
      Lwt.return
      @@ Error
           (Sihl.Error.authorization ~msg:"User is not allowed to set password"
              ())

  let confirm_email request token =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* token =
      Repository.Token.get ~value:token |> Sihl.Core.Db.query_db request
    in
    if not @@ Model.Token.is_valid_email_configuration token then
      Lwt.return
      @@ Error
           (Sihl.Error.bad_request ~msg:"invalid confirmation token provided"
              ())
    else
      Sihl.Core.Db.query_db_with_trx request (fun connection ->
          let* () =
            Repository.Token.update (Model.Token.inactivate token) connection
          in
          let* user = Repository.User.get ~id:token.user connection in
          Repository.User.update (Sihl.User.confirm user) connection)

  let request_password_reset request ~email =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* user =
      get_by_email request ~email |> Lwt.map Sihl.Error.not_found_of_opt
    in
    let token = Model.Token.create_password_reset user in
    let* () = Repository.Token.insert token |> Sihl.Core.Db.query_db request in
    let email = Model.Email.create_password_reset token user in
    Sihl_email.Service.send request email

  let reset_password request ~token ~new_password =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in

    let* token =
      Repository.Token.get ~value:token |> Sihl.Core.Db.query_db request
    in
    if not @@ Model.Token.can_reset_password token then
      Lwt.return
      @@ Error
           (Sihl.Error.bad_request ~msg:"Invalid or inactive token provided" ())
    else
      let* user =
        Repository.User.get ~id:token.user |> Sihl.Core.Db.query_db request
      in
      (* TODO use transaction here *)
      let updated_user = Sihl.User.update_password user new_password in
      let* () =
        Repository.User.update updated_user |> Sihl.Core.Db.query_db request
      in
      let token = Model.Token.inactivate token in
      Repository.Token.update token |> Sihl.Core.Db.query_db request
end
