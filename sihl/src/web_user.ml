let log_src = Logs.Src.create "sihl.middleware.user"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Contract_user.t Opium.Context.key =
  Opium.Context.Key.create ("user", Contract_user.to_sexp)
;;

exception User_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No user found");
    Logs.info (fun m ->
        m "Have you applied the user middleware for this route?");
    raise User_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set user req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key user env in
  { req with env }
;;

let middleware ?(key = "user_id") find_user =
  let open Lwt.Syntax in
  let filter handler req =
    match Web_session.find key req with
    | Some user_id ->
      let* user = find_user user_id in
      (match user with
      | Some user ->
        let req = set user req in
        handler req
      | None -> handler req)
    | None -> handler req
  in
  Rock.Middleware.create ~name:"session.user" ~filter
;;
