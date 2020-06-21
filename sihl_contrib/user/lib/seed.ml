let ( let* ) = Lwt.bind

let admin ~email ~password request =
  let (module UserService : Sihl.User.Sig.SERVICE) =
    Sihl.Container.fetch_service_exn Sihl.User.Sig.key
  in
  UserService.create_admin request ~email ~password ~username:None

let logged_in_admin ~email ~password request =
  let (module UserService : Sihl.User.Sig.SERVICE) =
    Sihl.Container.fetch_service_exn Sihl.User.Sig.key
  in
  let* user =
    UserService.create_admin request ~email ~password ~username:None
  in
  let* token = UserService.login request ~email ~password in
  Lwt.return (user, token)

let user ~email ~password request =
  let (module UserService : Sihl.User.Sig.SERVICE) =
    Sihl.Container.fetch_service_exn Sihl.User.Sig.key
  in
  UserService.register request ~email ~password ~username:None

let logged_in_user ~email ~password request =
  let (module UserService : Sihl.User.Sig.SERVICE) =
    Sihl.Container.fetch_service_exn Sihl.User.Sig.key
  in
  let* user = UserService.register request ~email ~password ~username:None in
  let* token = UserService.login request ~email ~password in
  Lwt.return (user, token)
