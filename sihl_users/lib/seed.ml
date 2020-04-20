let ( let* ) = Lwt.bind

let admin ~email ~password request =
  Service.User.create_admin request ~email ~password ~username:"admin"
    ~name:"Administrator"

let logged_in_admin ~email ~password request =
  let* _ =
    Service.User.create_admin request ~email ~password ~username:"admin"
      ~name:"Administrator"
  in
  Service.User.login request ~email ~password

let user ~email ~password request =
  Service.User.register request ~email ~password ~username:"username"
    ~name:"name"

let logged_in_user ~email ~password request =
  let* _ =
    Service.User.register request ~email ~password ~username:"username"
      ~name:"name"
  in
  Service.User.login request ~email ~password
