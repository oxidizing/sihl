let log_src = Logs.Src.create "sihl_token.middleware.user"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Sihl.Contract.User.t Opium.Context.key =
  Opium.Context.Key.create ("user", Sihl.Contract.User.to_sexp)
;;

exception User_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No user found");
    Logs.info (fun m ->
        m "Have you applied the user middleware in sihl-token for this route?");
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

let middleware read_token ?(key = "user_id") find_user =
  let open Lwt.Syntax in
  let filter handler req =
    match Sihl.Web.Bearer_token.find_opt req with
    | Some token ->
      let* user_id = read_token token ~k:key in
      (match user_id with
      | None -> handler req
      | Some user_id ->
        let* user = find_user user_id in
        (match user with
        | Some user ->
          let req = set user req in
          handler req
        | None -> handler req))
    | None -> handler req
  in
  Rock.Middleware.create ~name:"token.user" ~filter
;;
