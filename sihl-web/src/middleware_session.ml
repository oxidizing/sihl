open Lwt.Syntax
module Session = Sihl_type.Session

let log_src = Logs.Src.create "sihl.middleware.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Session.t Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("session", Session.sexp_of_t)
;;

let find req = Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set session req =
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add key session env in
  { req with env }
;;

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  let m ?(cookie_key = "session_key") () =
    let filter handler req =
      match Sihl_type.Http_request.cookie cookie_key req with
      | Some session_key ->
        (* A session cookie was found *)
        Logs.debug (fun m -> m "Found session cookie with value %s" session_key);
        let* session = SessionService.find_opt ~key:session_key in
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
          let scope = Uri.of_string "/" in
          Sihl_type.Http_response.add_cookie
            ~scope
            ~expires:`Session
            (cookie_key, session.key)
            res
          |> Lwt.return)
      | None ->
        Logs.debug (fun m -> m "No session cookie found, set a new one");
        (* No session cookie found *)
        let* session = SessionService.create [] in
        let req = set session req in
        let* res = handler req in
        let scope = Uri.of_string "/" in
        res
        |> Sihl_type.Http_response.add_cookie
             ~scope
             ~expires:`Session
             (cookie_key, session.key)
        |> Lwt.return
    in
    Opium_kernel.Rock.Middleware.create ~name:"session" ~filter
  ;;
end
