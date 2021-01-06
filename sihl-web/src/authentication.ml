open Sexplib.Std

let log_src = Logs.Src.create "sihl.middleware.authentication"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type credentials =
  { email : string
  ; password : string
  }
[@@deriving sexp]

let key_login : credentials Opium.Context.key =
  Opium.Context.Key.create ("authenticate.login", sexp_of_credentials)
;;

let login ~email ~password res =
  let env = res.Opium.Response.env in
  let credentials = { email; password } in
  let env = Opium.Context.add key_login credentials env in
  { res with env }
;;

let default_site_error_handler _ =
  Lwt.return
    (Opium.Response.of_plain_text "" |> Opium.Response.set_status `Unauthorized)
;;

let session_middleware
    ?(key = "authn")
    ?(error_handler = default_site_error_handler)
    ()
  =
  let open Lwt.Syntax in
  let filter handler req =
    let* resp = handler req in
    let env = resp.Opium.Response.env in
    match Session.find_opt req, Opium.Context.find key_login env with
    | Some session, Some { email; password } ->
      let* user = Sihl_facade.User.login ~email ~password in
      (match user with
      | Error error -> error_handler error
      | Ok user ->
        let* () =
          Sihl_facade.Session.set_value session ~k:key ~v:(Some user.id)
        in
        Lwt.return resp)
    | Some _, None -> handler req
    | None, Some _ -> handler req
    | None, None -> handler req
  in
  Rock.Middleware.create ~name:"user.session" ~filter
;;

let default_json_error_handler _ =
  let msg = {|{"errors": ["Invalid email or password provided"]}|} in
  Lwt.return
    (Opium.Response.of_plain_text msg
    |> Opium.Response.set_status `Unauthorized
    |> Opium.Response.set_content_type "application/json")
;;

let token_middleware
    ?(key = "token")
    ?(error_handler = default_json_error_handler)
    ()
  =
  let open Lwt.Syntax in
  let filter handler req =
    let* resp = handler req in
    let env = resp.Opium.Response.env in
    match Opium.Context.find key_login env with
    | None -> Lwt.return resp
    | Some { email; password } ->
      let* user = Sihl_facade.User.login ~email ~password in
      (match user with
      | Error error -> error_handler error
      | Ok user ->
        let* token = Sihl_facade.Token.create [ "user_id", user.id ] in
        let msg = Format.sprintf {|{"%s": "%s"}|} key token in
        Lwt.return
          (Opium.Response.of_plain_text msg
          |> Opium.Response.set_content_type "application/json"))
  in
  Rock.Middleware.create ~name:"user.token" ~filter
;;
