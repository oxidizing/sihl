let ( let* ) = Lwt.bind

let user ~email ~password request =
  Service.User.register request ~email ~password ~username:"username"
    ~name:"name"

let logged_in_user ~email ~password request =
  let* _ =
    Service.User.register request ~email ~password ~username:"username"
      ~name:"name"
  in
  Service.User.login request ~email ~password
