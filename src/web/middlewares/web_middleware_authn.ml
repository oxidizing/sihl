let ( let* ) = Lwt.bind

module Make (AuthnService : Authn.Sig.SERVICE) = struct
  let session () =
    let filter handler ctx =
      let* user = AuthnService.find_user_in_session ctx in
      match user with
      | Ok (Some user) ->
          let ctx = User.ctx_add_user user ctx in
          handler ctx
      | Ok None -> handler ctx
      | Error msg ->
          Logs.err (fun m -> m "MIDDLEWARE: Failed to authenticate %s" msg);
          failwith msg
    in
    Web_middleware_core.create ~name:"authn_session" filter

  let require_user ~login_path_f =
    let filter handler ctx =
      let user = User.find_user ctx in
      match user with
      | Some _ -> handler ctx
      | None ->
          let login_path = login_path_f () in
          Web_res.redirect login_path |> Lwt.return
    in
    Web_middleware_core.create ~name:"user_require_user" filter

  let require_admin ~login_path_f =
    let filter handler ctx =
      let user = User.find_user ctx in
      match user with
      | Some user ->
          if User.is_admin user then handler ctx
          else
            let login_path = login_path_f () in
            Web_res.redirect login_path |> Lwt.return
      | None ->
          let login_path = login_path_f () in
          Web_res.redirect login_path |> Lwt.return
    in
    Web_middleware_core.create ~name:"user_require_admin" filter
end

(* let token () =
 *   let filter handler req =
 *     let ctx = Http.ctx req in
 *     match req |> Request.headers |> Cohttp.Header.get_authorization with
 *     | None -> handler req
 *     | Some (`Other token) -> (
 *         (\* TODO use more robust bearer token parsing *\)
 *         let token =
 *           token |> String.split ~on:' ' |> List.tl_exn |> List.hd_exn
 *         in
 *         let (module UserService : User.Sig.SERVICE) =
 *           Core.Container.fetch_service_exn User.Sig.key
 *         in
 *         let* user =
 *           UserService.get_by_token ctx token
 *           |> Lwt_result.map_err Core.Err.raise_not_authenticated
 *           |> Lwt.map Result.ok_exn
 *         in
 *         match user with
 *         | None -> Core.Err.raise_not_authenticated "No user found"
 *         | Some user ->
 *             let env = Opium.Hmap.add key user (Request.env req) in
 *             let req = { req with Request.env } in
 *             handler req )
 *     | Some (`Basic (email, password)) ->
 *         let (module UserService : User.Sig.SERVICE) =
 *           Core.Container.fetch_service_exn User.Sig.key
 *         in
 *         let* user =
 *           UserService.authenticate_credentials ctx ~email ~password
 *           |> Lwt_result.map_err Core.Err.raise_not_authenticated
 *           |> Lwt.map Result.ok_exn
 *         in
 *         let env = Opium.Hmap.add key user (Request.env req) in
 *         let req = { req with Request.env } in
 *         handler req
 *   in
 *   Rock.Middleware.create ~name:"users.token" ~filter *)
