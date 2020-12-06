open Lwt.Syntax
module Session = Sihl_type.Session

let log_src = Logs.Src.create "sihl.middleware.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Session_not_found

let key : Session.t Opium.Context.key =
  Opium.Context.Key.create ("session", Session.sexp_of_t)
;;

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No session found");
    Logs.info (fun m -> m "Have you applied the session middleware for this route?");
    raise @@ Session_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set session req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key session env in
  { req with env }
;;

let add_session_cookie cookie_name session_key signer res =
  let scope = Uri.of_string "/" in
  Sihl_type.Http_response.add_cookie_unless_exists
    ~sign_with:signer
    ~scope
    ~expires:`Session
    (cookie_name, session_key)
    res
;;

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  let m ?(cookie_name = "sihl.session") () =
    let filter handler req =
      let secret = Sihl_core.Configuration.read_secret () in
      let signer = Sihl_type.Http_cookie.Signer.make secret in
      match Sihl_type.Http_request.cookie ~signed_with:signer cookie_name req with
      | Some session_key ->
        (* A session cookie was found *)
        Logs.debug (fun m -> m "Found session cookie with value %s" session_key);
        let* session = SessionService.find_opt session_key in
        (match session with
        | Some session ->
          Logs.debug (fun m -> m "Found session for cookie %s" session_key);
          let* session =
            if Session.is_expired (Ptime_clock.now ()) session
            then (
              Logs.debug (fun m -> m "Session expired, creating new one");
              let* session = SessionService.create [] in
              Lwt.return session)
            else Lwt.return session
          in
          let req = set session req in
          handler req
        | None ->
          Logs.debug (fun m -> m "No session found for cookie %s" session_key);
          let* session = SessionService.create [] in
          let req = set session req in
          let* res = handler req in
          add_session_cookie cookie_name session.key signer res |> Lwt.return)
      | None ->
        Logs.debug (fun m -> m "No session cookie found, set a new one");
        (* No session cookie found *)
        let* session = SessionService.create [] in
        let req = set session req in
        let* res = handler req in
        add_session_cookie cookie_name session.key signer res |> Lwt.return
    in
    Rock.Middleware.create ~name:"session" ~filter
  ;;
end
