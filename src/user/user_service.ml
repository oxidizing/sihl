open Base

let ( let* ) = Lwt_result.bind

module Make (UserRepo : User_sig.REPOSITORY) : User.Sig.SERVICE = struct
  let on_bind req =
    let* () = Migration.register req (UserRepo.migrate ()) in
    Repo.register_cleaner req UserRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get ctx ~user_id = UserRepo.get ~id:user_id |> Core.Db.query ctx

  let get_by_email ctx ~email =
    UserRepo.get_by_email ~email |> Core.Db.query ctx

  let get_all ctx = UserRepo.get_all |> Core.Db.query ctx

  let update_password ctx ~email ~old_password ~new_password =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update password")
    in
    let* () = User.validate user ~old_password ~new_password |> Lwt.return in
    let updated_user = User.set_user_password user new_password in
    let* () = UserRepo.update ~user:updated_user |> Core.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let update_details ctx ~email ~username =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update details")
    in
    let updated_user = User.set_user_details user ~email ~username in
    let* () = UserRepo.update ~user:updated_user |> Core.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let set_password ctx ~user_id ~password =
    let* user =
      get ctx ~user_id
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to set password")
    in
    let* () = User.validate_password password |> Lwt.return in
    let updated_user = User.set_user_password user password in
    let* () = UserRepo.update ~user:updated_user |> Core.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let create_user ctx ~email ~password ~username =
    let user =
      User.create ~email ~password ~username ~admin:false ~confirmed:false
    in
    let* () = UserRepo.insert ~user |> Core.Db.query ctx in
    Lwt.return @@ Ok user

  let create_admin ctx ~email ~password ~username =
    let* user = UserRepo.get_by_email ~email |> Core.Db.query ctx in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      User.create ~email ~password ~username ~admin:true ~confirmed:true
    in
    let* () = UserRepo.insert ~user |> Core.Db.query ctx in
    Lwt.return @@ Ok user
end

module UserMariaDb = Make (User_service_repo.MariaDb)

let mariadb =
  Core.Container.create_binding User.Sig.key
    (module UserMariaDb)
    (module UserMariaDb)

module UserPostgreSql = Make (User_service_repo.PostgreSql)

let postgresql =
  Core.Container.create_binding User.Sig.key
    (module UserPostgreSql)
    (module UserPostgreSql)
