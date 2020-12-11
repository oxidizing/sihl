let session =
  let open Lwt.Syntax in
  let filter handler req =
    match Middleware_session.find_opt req with
    | Some session ->
      let* user = Sihl_facade.Authn.find_user_in_session_opt session in
      (match user with
      | Some user ->
        let req = Middleware_user.set user req in
        handler req
      | None -> handler req)
    | None -> handler req
  in
  Rock.Middleware.create ~name:"authn.session" ~filter
;;
