open Base
open Lwt.Syntax
module Repo = User_service_repo
module User = User_core.User
module Sig = User_service_sig

module Make
    (Log : Log.Service.Sig.SERVICE)
    (CmdService : Cmd.Service.Sig.SERVICE)
    (DbService : Data.Db.Service.Sig.SERVICE)
    (Repo : Sig.REPOSITORY) : Sig.SERVICE = struct
  let add_user user ctx = Core.Ctx.add User.ctx_key user ctx

  let require_user_opt ctx = Core.Ctx.find User.ctx_key ctx

  let require_user ctx =
    match Core.Ctx.find User.ctx_key ctx with
    | None -> raise (User_core.Exception "User not found in context")
    | Some user -> user

  let find_opt ctx ~user_id = Repo.get ctx ~id:user_id

  let find ctx ~user_id =
    let* m_user = find_opt ctx ~user_id in
    match m_user with
    | Some user -> Lwt.return user
    | None ->
        Log.err (fun m -> m "USER: User not found with id %s" user_id);
        raise (User_core.Exception "User not found")

  let find_by_email_opt ctx ~email =
    (* TODO add support for lowercase UTF-8
     * String.lowercase only supports US-ASCII, but
     * email addresses can contain other letters
     * (https://tools.ietf.org/html/rfc6531) like umlauts.
     *)
    Repo.get_by_email ctx ~email:(String.lowercase email)

  let find_by_email ctx ~email =
    let* user = find_by_email_opt ctx ~email in
    match user with
    | Some user -> Lwt.return user
    | None ->
        Log.err (fun m -> m "USER: User not found with email %s" email);
        raise (User_core.Exception "User not found")

  let find_all ctx ~query = Repo.get_all ctx ~query

  let update_password ctx ?(password_policy = User.default_password_policy)
      ~user ~old_password ~new_password ~new_password_confirmation () =
    match
      User.validate_change_password user ~old_password ~new_password
        ~new_password_confirmation ~password_policy
    with
    | Ok () ->
        let updated_user =
          match User.set_user_password user new_password with
          | Ok user -> user
          | Error msg ->
              Log.err (fun m ->
                  m "USER: Can not update password of user %s: %s"
                    (User.email user) msg);
              raise (User_core.Exception msg)
        in
        let* () = Repo.update ~user:updated_user ctx in
        Lwt.return @@ Ok updated_user
    | Error msg -> Lwt.return @@ Error msg

  let update_details ctx ~user ~email ~username =
    let updated_user = User.set_user_details user ~email ~username in
    let* () = Repo.update ctx ~user:updated_user in
    find ctx ~user_id:(User.id user)

  let set_password ctx ?(password_policy = User.default_password_policy) ~user
      ~password ~password_confirmation () =
    let* result =
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
      |> Lwt.return
    in
    match result with
    | Error msg -> Lwt.return @@ Error msg
    | Ok () ->
        let updated_user =
          match User.set_user_password user password with
          | Ok user -> user
          | Error msg ->
              Log.err (fun m ->
                  m "USER: Can not set password of user %s: %s"
                    (User.email user) msg);
              raise (User_core.Exception msg)
        in
        let* () = Repo.update ctx ~user:updated_user in
        Lwt_result.return updated_user

  let create_user ctx ~email ~password ~username =
    let user =
      match
        User.create ~email ~password ~username ~admin:false ~confirmed:false
      with
      | Ok user -> user
      | Error msg -> raise (User_core.Exception msg)
    in
    let* () = Repo.insert ctx ~user in
    Lwt.return user

  let create_admin ctx ~email ~password ~username =
    let* user = Repo.get_by_email ctx ~email in
    let* () =
      match user with
      | Some _ ->
          Log.err (fun m ->
              m "USER: Can not create admin %s since the email is already taken"
                email);
          raise (User_core.Exception "Email already taken")
      | None -> Lwt.return ()
    in
    let user =
      match
        User.create ~email ~password ~username ~admin:true ~confirmed:true
      with
      | Ok user -> user
      | Error msg ->
          Log.err (fun m -> m "USER: Can not create admin %s %s" email msg);
          raise (User_core.Exception msg)
    in
    let* () = Repo.insert ctx ~user in
    Lwt.return user

  let register ctx ?(password_policy = User.default_password_policy) ?username
      ~email ~password ~password_confirmation () =
    match
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
    with
    | Error msg -> Lwt_result.fail msg
    | Ok () -> (
        let* user = find_by_email_opt ctx ~email in
        match user with
        | None ->
            create_user ctx ~username ~email ~password |> Lwt.map Result.return
        | Some _ -> Lwt_result.fail "Invalid email address provided" )

  let login ctx ~email ~password =
    let* user = find_by_email_opt ctx ~email in
    match user with
    | None -> Lwt_result.fail "Invalid email or password provided"
    | Some user ->
        if User.matches_password password user then Lwt_result.return user
        else Lwt_result.fail "Invalid email or password provided"

  let create_admin_cmd =
    Cmd.make ~name:"createadmin" ~help:"<username> <email> <password>"
      ~description:"Create an admin user"
      ~fn:(fun args ->
        match args with
        | [ username; email; password ] ->
            let ctx = Core.Ctx.empty |> DbService.add_pool in
            create_admin ctx ~email ~password ~username:(Some username)
            |> Lwt.map ignore
        | _ -> raise (Cmd.Invalid_usage "Usage: <username> <email> <password>"))
      ()

  let start ctx =
    Repo.register_migration ();
    Repo.register_cleaner ();
    CmdService.register_command create_admin_cmd;
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.make "user"
      ~dependencies:[ Log.lifecycle; CmdService.lifecycle; DbService.lifecycle ]
      ~start ~stop
end
