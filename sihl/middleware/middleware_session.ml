open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"Session Middleware" "sihl.middleware.session"

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

module Make (SessionService : Session.Sig.SERVICE) = struct
  let m ?(cookie_key = "session_key") () =
    let filter handler req =
      let ctx = Http.Request.to_ctx req in
      match Http.Request.cookie cookie_key req with
      | Some session_key ->
        (* A session cookie was found *)
        let* session = SessionService.find_opt ctx ~key:session_key in
        (match session with
        | Some session ->
          let* session =
            if Session.is_expired (Ptime_clock.now ()) session
            then (
              Logs.debug (fun m -> m "SESSION: Session expired, creating new one");
              let* session = SessionService.create ctx [] in
              Lwt.return session)
            else Lwt.return session
          in
          let req = set session req in
          handler req
        | None ->
          let* session = SessionService.create ctx [] in
          let req = set session req in
          let* res = handler req in
          Http.Response.add_cookie (cookie_key, session.key) res |> Lwt.return)
      | None ->
        (* No session cookie found *)
        let* session = SessionService.create ctx [] in
        let req = set session req in
        let* res = handler req in
        res |> Http.Response.add_cookie (cookie_key, session.key) |> Lwt.return
    in
    Opium_kernel.Rock.Middleware.create ~name:"session" ~filter
  ;;
end
