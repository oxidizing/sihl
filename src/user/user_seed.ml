let ( let* ) = Lwt.bind

module Make (UserService : User_sig.SERVICE) = struct
  let admin ~email ~password request =
    UserService.create_admin request ~email ~password ~username:None

  (* let logged_in_admin ~email ~password request =
   *   let (module UserService : User_sig.SERVICE) =
   *     Core.Container.fetch_service_exn User_sig.key
   *   in
   *   let* user =
   *     UserService.create_admin request ~email ~password ~username:None
   *   in
   *   let* token = UserService.login request ~email ~password in
   *   Lwt.return (user, token) *)

  let user ~email ~password ?username request =
    UserService.create_user request ~email ~password ~username

  (* let logged_in_user ~email ~password request =
   *   let (module UserService : User_sig.SERVICE) =
   *     Core.Container.fetch_service_exn User_sig.key
   *   in
   *   let* user = UserService.register request ~email ~password ~username:None in
   *   let* token = UserService.login request ~email ~password in
   *   Lwt.return (user, token) *)
end
