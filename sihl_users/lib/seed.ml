let ( let* ) = Lwt.bind

let admin ~email ~password request =
  Service.User.create_admin request ~email ~password ~username:"admin"
    ~name:"Administrator"

let logged_in_admin ~email ~password request =
  let* user =
    Service.User.create_admin request ~email ~password ~username:"admin"
      ~name:"Administrator"
  in
  let* token = Service.User.login request ~email ~password in
  Lwt.return (user, token)

let user ~email ~password request =
  Service.User.register request ~email ~password ~username:"username"
    ~name:"name"

let logged_in_user ~email ~password request =
  let* user =
    Service.User.register request ~email ~password ~username:"username"
      ~name:"name"
  in
  let* token = Service.User.login request ~email ~password in
  Lwt.return (user, token)
