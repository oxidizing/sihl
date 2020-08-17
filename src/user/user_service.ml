open Base

let ( let* ) = Lwt_result.bind

module Repo = User_service_repo
module User = User_core.User

module Make
    (CmdService : Cmd.Sig.SERVICE)
    (DbService : Data.Db.Sig.SERVICE)
    (Repo : User_sig.REPOSITORY) : User_sig.SERVICE = struct
  let get ctx ~user_id = Repo.get ctx ~id:user_id

  let get_exn ctx ~user ~msg =
    let* user = get ctx ~user_id:(User.id user) in
    match user with
    | Some user -> Lwt_result.return user
    | None ->
        Logs.err (fun m -> m "%s" msg);
        Lwt_result.fail msg

  let get_by_email ctx ~email =
    (* TODO add support for lowercase UTF-8
     * String.lowercase only supports US-ASCII, but
     * email addresses can contain other letters
     * (https://tools.ietf.org/html/rfc6531) like umlauts.
     *)
    Repo.get_by_email ctx ~email:(String.lowercase email)

  let get_all ctx ~query = Repo.get_all ctx ~query

  let update_password ctx ?(password_policy = User.default_password_policy)
      ~user ~old_password ~new_password ~new_password_confirmation () =
    match
      User.validate_change_password user ~old_password ~new_password
        ~new_password_confirmation ~password_policy
    with
    | Ok () ->
        let updated_user = User.set_user_password user new_password in
        let* () = Repo.update ~user:updated_user ctx in
        Lwt_result.return @@ Ok updated_user
    | Error msg -> Lwt_result.return @@ Error msg

  let update_details ctx ~user ~email ~username =
    let updated_user = User.set_user_details user ~email ~username in
    let* () = Repo.update ctx ~user:updated_user in
    get_exn ctx ~user ~msg:("Failed to update user with email " ^ email)

  let set_password ctx ?(password_policy = User.default_password_policy) ~user
      ~password ~password_confirmation () =
    let* result =
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
      |> Lwt_result.return
    in
    match result with
    | Error msg -> Lwt_result.return @@ Error msg
    | Ok () ->
        let updated_user = User.set_user_password user password in
        let* () = Repo.update ctx ~user:updated_user in
        Lwt_result.return @@ Ok updated_user

  let create_user ctx ~email ~password ~username =
    let user =
      User.create ~email ~password ~username ~admin:false ~confirmed:false
    in
    let* () = Repo.insert ctx ~user in
    Lwt.return @@ Ok user

  let create_admin ctx ~email ~password ~username =
    let* user = Repo.get_by_email ctx ~email in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      User.create ~email ~password ~username ~admin:true ~confirmed:true
    in
    let* () = Repo.insert ctx ~user in
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

  let create_admin_cmd =
    Cmd.make ~name:"createadmin" ~help:"<username> <email> <password>"
      ~description:"Create an admin user"
      ~fn:(fun args ->
        match args with
        | [ username; email; password ] ->
            let ctx = Core.Ctx.empty |> DbService.add_pool in
            create_admin ctx ~email ~password ~username:(Some username)
            |> Lwt_result.map ignore
        | _ -> Lwt_result.fail "Usage: <username> <email> <password>")
      ()

  let lifecycle =
    Core.Container.Lifecycle.make "user"
      ~dependencies:[ CmdService.lifecycle; DbService.lifecycle ]
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         let* () = Repo.register_cleaner ctx in
         Cmd_service.register_command ctx create_admin_cmd)
        |> Lwt.map Result.ok_or_failwith
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())
end
