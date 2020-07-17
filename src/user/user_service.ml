open Base

let ( let* ) = Lwt_result.bind

module User = User_core.User

module Make
    (UserRepo : User_sig.REPOSITORY)
    (MigrationService : Data.Migration.Sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE) : User_sig.SERVICE = struct
  let on_init ctx =
    let* () = MigrationService.register ctx (UserRepo.migrate ()) in
    RepoService.register_cleaner ctx UserRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get ctx ~user_id = UserRepo.get ~id:user_id |> Data.Db.query ctx

  let get_exn ctx ~user ~msg =
    let* user = get ctx ~user_id:(User.id user) in
    match user with
    | Some user -> Lwt_result.return user
    | None ->
        Logs.err (fun m -> m "%s" msg);
        Lwt_result.fail msg

  let get_by_email ctx ~email =
    UserRepo.get_by_email ~email |> Data.Db.query ctx

  let get_all ctx ~query = UserRepo.get_all ~query |> Data.Db.query ctx

  let update_password ctx ?(password_policy = User.default_password_policy)
      ~user ~old_password ~new_password ~new_password_confirmation () =
    match
      User.validate_change_password user ~old_password ~new_password
        ~new_password_confirmation ~password_policy
    with
    | Ok () ->
        let updated_user = User.set_user_password user new_password in
        let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
        Lwt_result.return @@ Ok updated_user
    | Error msg -> Lwt_result.return @@ Error msg

  let update_details ctx ~user ~email ~username =
    let updated_user = User.set_user_details user ~email ~username in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    get_exn ctx ~user ~msg:("Failed to update user with email " ^ email)

  let set_password ctx ?(password_policy = User.default_password_policy) ~user
      ~password ~password_confirmation () =
    let* () =
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
      |> Lwt.return
    in
    let updated_user = User.set_user_password user password in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let create_user ctx ~email ~password ~username =
    let user =
      User.create ~email ~password ~username ~admin:false ~confirmed:false
    in
    let* () = UserRepo.insert ~user |> Data.Db.query ctx in
    Lwt.return @@ Ok user

  let create_admin ctx ~email ~password ~username =
    let* user = UserRepo.get_by_email ~email |> Data.Db.query ctx in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      User.create ~email ~password ~username ~admin:true ~confirmed:true
    in
    let* () = UserRepo.insert ~user |> Data.Db.query ctx in
    Lwt.return @@ Ok user

  let register ctx ?(password_policy = User.default_password_policy) ?username
      ~email ~password ~password_confirmation () =
    match
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
    with
    | Error msg -> Lwt_result.return @@ Error msg
    | Ok () -> (
        let* user = get_by_email ctx ~email in
        match user with
        | None ->
            create_user ctx ~username ~email ~password
            |> Lwt_result.map (fun user -> Ok user)
        | Some _ -> Lwt_result.return (Error "Invalid email address provided") )

  let login ctx ~email ~password =
    let* user =
      get_by_email ctx ~email
      |> Lwt_result.map
           (Result.of_option ~error:"Invalid email or password provided")
    in
    match user with
    | Ok user ->
        if User.matches_password password user then Lwt_result.return @@ Ok user
        else Lwt_result.return @@ Error "Invalid email or password provided"
    | Error msg -> Lwt_result.return @@ Error msg
end
