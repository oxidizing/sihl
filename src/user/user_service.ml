open Base

let ( let* ) = Lwt_result.bind

module User = User_model.User

module Make (UserRepo : User_sig.REPOSITORY) : User_sig.SERVICE = struct
  let on_bind ctx =
    let* () = Data.Migration.register ctx (UserRepo.migrate ()) in
    Data.Repo.register_cleaner ctx UserRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get ctx ~user_id = UserRepo.get ~id:user_id |> Data.Db.query ctx

  let get_by_email ctx ~email =
    UserRepo.get_by_email ~email |> Data.Db.query ctx

  let get_all ctx = UserRepo.get_all |> Data.Db.query ctx

  let update_password ctx ~email ~old_password ~new_password =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update password")
    in
    let* () = User.validate user ~old_password ~new_password |> Lwt.return in
    let updated_user = User.set_user_password user new_password in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let update_details ctx ~email ~username =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update details")
    in
    let updated_user = User.set_user_details user ~email ~username in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let set_password ctx ~user_id ~password =
    let* user =
      get ctx ~user_id
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to set password")
    in
    let* () = User.validate_password password |> Lwt.return in
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
end

module UserMariaDb = Make (User_service_repo.MariaDb)

let mariadb =
  Core.Container.create_binding User_sig.key
    (module UserMariaDb)
    (module UserMariaDb)

module UserPostgreSql = Make (User_service_repo.PostgreSql)

let postgresql =
  Core.Container.create_binding User_sig.key
    (module UserPostgreSql)
    (module UserPostgreSql)

let get req ~user_id =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get req ~user_id

let get_by_email req ~email =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get_by_email req ~email

let get_all req =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get_all req

let update_password req ~email ~old_password ~new_password =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.update_password req ~email ~old_password ~new_password

let set_password req ~user_id ~password =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.set_password req ~user_id ~password

let update_details req ~email ~username =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.update_details req ~email ~username

let create_user req ~email ~password ~username =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.create_user req ~email ~password ~username

let create_admin req ~email ~password ~username =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.create_admin req ~email ~password ~username
