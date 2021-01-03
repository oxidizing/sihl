let user ~login_path_f =
  let filter handler req =
    let user = User.find_opt req in
    match user with
    | Some _ -> handler req
    | None ->
      let login_path = login_path_f () in
      Opium.Response.redirect_to login_path |> Lwt.return
  in
  Rock.Middleware.create ~name:"authorization.user" ~filter
;;

let admin ~login_path_f =
  let filter handler req =
    let user = User.find_opt req in
    match user with
    | Some user ->
      if Sihl_facade.User.is_admin user
      then handler req
      else (
        let login_path = login_path_f () in
        Opium.Response.redirect_to login_path |> Lwt.return)
    | None ->
      let login_path = login_path_f () in
      Opium.Response.redirect_to login_path |> Lwt.return
  in
  Rock.Middleware.create ~name:"authorization.admin" ~filter
;;
