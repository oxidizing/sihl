let log_src =
  Logs.Src.create ("sihl.service." ^ Sihl.Contract.Password_reset.name)
;;

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make
    (UserService : Sihl.Contract.User.Sig)
    (TokenService : Sihl.Contract.Token.Sig) =
struct
  let create_reset_token ~email =
    let%lwt user = UserService.find_by_email_opt email in
    match user with
    | Some user ->
      let user_id = user.id in
      TokenService.create ~expires_in:Sihl.Time.OneDay [ "user_id", user_id ]
      |> Lwt.map Option.some
    | None ->
      Logs.warn (fun m -> m "No user found with email %s" email);
      Lwt.return None
  ;;

  let reset_password ~token ~password ~password_confirmation =
    let%lwt user_id = TokenService.read token ~k:"user_id" in
    match user_id with
    | None -> Lwt.return @@ Error "Token invalid or not assigned to any user"
    | Some user_id ->
      let%lwt user = UserService.find user_id in
      let%lwt result =
        UserService.set_password user ~password ~password_confirmation
      in
      Lwt.return @@ Result.map (fun _ -> ()) result
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Password_reset.name
      ~start
      ~stop
      ~dependencies:(fun () ->
        [ TokenService.lifecycle; UserService.lifecycle ])
  ;;

  let register () = Sihl.Container.Service.create lifecycle
end
