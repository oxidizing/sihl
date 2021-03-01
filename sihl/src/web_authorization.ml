let user ~login_path_f =
  let filter handler req =
    let user = Web_user.find_opt req in
    match user with
    | Some _ -> handler req
    | None ->
      let login_path = login_path_f () in
      Opium.Response.redirect_to login_path |> Lwt.return
  in
  Rock.Middleware.create ~name:"authorization.user" ~filter
;;

let admin ~login_path_f is_admin =
  let filter handler req =
    let user = Web_user.find_opt req in
    match user with
    | Some user ->
      if is_admin user
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
