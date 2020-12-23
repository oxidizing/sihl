let log_src = Logs.Src.create "sihl.middleware.user.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Sihl_contract.User.t Opium.Context.key =
  Opium.Context.Key.create ("user", Sihl_contract.User.sexp_of_t)
;;

let find req = Opium.Context.find_exn key req.Opium.Request.env
let find_opt req = Opium.Context.find key req.Opium.Request.env

let set user req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key user env in
  { req with env }
;;

let key_login : Sihl_contract.User.t option Opium.Context.key =
  Opium.Context.Key.create
    ("user.login", Sexplib.Std.sexp_of_option Sihl_contract.User.sexp_of_t)
;;

let login user res =
  let env = res.Opium.Response.env in
  let env = Opium.Context.add key_login (Some user) env in
  { res with env }
;;

let logout res =
  let env = res.Opium.Response.env in
  let env = Opium.Context.add key_login None env in
  { res with env }
;;

let handle_login_logout_session resp key session =
  let open Lwt.Syntax in
  let env = resp.Opium.Response.env in
  match Opium.Context.find key_login env with
  | Some (Some user) ->
    let* () =
      Sihl_facade.Session.set_value session ~k:key ~v:(Some (Sihl_contract.User.id user))
    in
    Lwt.return resp
  | Some None ->
    let* () = Sihl_facade.Session.set_value session ~k:key ~v:None in
    Lwt.return resp
  | None ->
    (* Nothing to do, whether login nor logout was called *)
    Lwt.return resp
;;

let session_middleware ?(key = "authn") () =
  let open Lwt.Syntax in
  let filter handler req =
    match Session.find_opt req with
    | Some session ->
      let* user =
        let* user_id = Sihl_facade.Session.find_value session key in
        match user_id with
        | None -> Lwt.return None
        | Some user_id -> Sihl_facade.User.find_opt ~user_id
      in
      (match user with
      | Some user ->
        let req = set user req in
        let* resp = handler req in
        handle_login_logout_session resp key session
      | None ->
        let* () = Sihl_facade.Session.set_value session ~k:key ~v:None in
        let* resp = handler req in
        handle_login_logout_session resp key session)
    | None ->
      let* resp = handler req in
      let env = resp.Opium.Response.env in
      let () =
        match Opium.Context.find key_login env with
        | Some (Some _) ->
          Logs.warn (fun m ->
              m
                "You called Sihl.Web.User.login(), but I didn't find a session that I \
                 can authenticate. Make sure that Sihl.Web.Session.middleware is \
                 registered before Sihl.Web.User.middleware_session")
        | Some None ->
          Logs.warn (fun m ->
              m
                "You called Sihl.Web.User.logout(), but I didn't find a session that I \
                 can unauthenticate. Make sure that Sihl.Web.Session.middleware is \
                 registered before Sihl.Web.User.middleware_session")
        | None -> ()
      in
      Lwt.return resp
  in
  Rock.Middleware.create ~name:"user.session" ~filter
;;

let handle_login_logout_token resp token =
  let env = resp.Opium.Response.env in
  match Opium.Context.find key_login env with
  | Some (Some _) ->
    token |> ignore;
    (* TODO [jerben] 1. create session token 2. associate user with token 3. update token *)
    Lwt.return resp
  | Some None ->
    (* TODO [jerben] 1. find token 2. remove token *)
    Lwt.return resp
  | None ->
    (* Nothing to do, whether login nor logout was called *)
    Lwt.return resp
;;

let token_middleware =
  let open Lwt.Syntax in
  let filter handler req =
    match Bearer_token.find_opt req with
    | Some token ->
      let* token = Sihl_facade.Token.find token in
      let* user =
        match token.Sihl_contract.Token.data with
        | Some user_id -> Sihl_facade.User.find_opt ~user_id
        | None -> Lwt.return None
      in
      (match user with
      | Some user ->
        let req = set user req in
        let* resp = handler req in
        handle_login_logout_token resp token
      | None ->
        let* resp = handler req in
        handle_login_logout_token resp token)
    | None ->
      let* resp = handler req in
      let env = resp.Opium.Response.env in
      let () =
        match Opium.Context.find key_login env with
        | Some (Some _) ->
          Logs.warn (fun m ->
              m
                "You called Sihl.Web.User.login(), but I didn't find a token that I can \
                 authenticate. Make sure that Sihl.Web.Bearer_token.middleware is \
                 registered before Sihl.Web.User.middleware_token")
        | Some None ->
          Logs.warn (fun m ->
              m
                "You called Sihl.Web.User.logout(), but I didn't find a token that I can \
                 unauthenticate. Make sure that Sihl.Web.Bearer_token.middleware is \
                 registered before Sihl.Web.User.middleware_token")
        | None -> ()
      in
      Lwt.return resp
  in
  Rock.Middleware.create ~name:"user.token" ~filter
;;
