open Lwt.Syntax

module Make
    (AuthnService : Authn.Service.Sig.SERVICE)
    (UserService : User.Service.Sig.SERVICE) =
struct
  let session () =
    let filter handler ctx =
      let* user = AuthnService.find_user_in_session_opt ctx in
      match user with
      | Some user ->
          let ctx = UserService.add_user user ctx in
          handler ctx
      | None -> handler ctx
    in
    Middleware_core.create ~name:"authn_session" filter

  let require_user ~login_path_f =
    let filter handler ctx =
      let user = UserService.require_user_opt ctx in
      match user with
      | Some _ -> handler ctx
      | None ->
          let login_path = login_path_f () in
          Http.Res.redirect login_path |> Lwt.return
    in
    Middleware_core.create ~name:"user_require_user" filter

  let require_admin ~login_path_f =
    let filter handler ctx =
      let user = UserService.require_user_opt ctx in
      match user with
      | Some user ->
          if User.is_admin user then handler ctx
          else
            let login_path = login_path_f () in
            Http.Res.redirect login_path |> Lwt.return
      | None ->
          let login_path = login_path_f () in
          Http.Res.redirect login_path |> Lwt.return
    in
    Middleware_core.create ~name:"user_require_admin" filter
end
