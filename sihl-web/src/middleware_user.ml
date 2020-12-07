module User = Sihl_type.User

let key : User.t Opium.Context.key = Opium.Context.Key.create ("user", User.sexp_of_t)
let find req = Opium.Context.find_exn key req.Opium.Request.env
let find_opt req = Opium.Context.find key req.Opium.Request.env

let set user req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key user env in
  { req with env }
;;

module Make (UserService : Sihl_contract.User.Sig) = struct
  let require_user ~login_path_f =
    let filter handler req =
      let user = find_opt req in
      match user with
      | Some _ -> handler req
      | None ->
        let login_path = login_path_f () in
        Sihl_type.Http_response.redirect_to login_path |> Lwt.return
    in
    Rock.Middleware.create ~name:"user.require.user" ~filter
  ;;

  let require_admin ~login_path_f =
    let filter handler req =
      let user = find_opt req in
      match user with
      | Some user ->
        if User.is_admin user
        then handler req
        else (
          let login_path = login_path_f () in
          Sihl_type.Http_response.redirect_to login_path |> Lwt.return)
      | None ->
        let login_path = login_path_f () in
        Sihl_type.Http_response.redirect_to login_path |> Lwt.return
    in
    Rock.Middleware.create ~name:"user.require.admin" ~filter
  ;;
end
