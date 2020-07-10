let ( let* ) = Lwt.bind

let session () =
  let filter handler ctx =
    let* user = Authn.find_user_in_session ctx in
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
