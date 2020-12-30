let log_src = Logs.Src.create "sihl.middleware.user"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Sihl_contract.User.t Opium.Context.key =
  Opium.Context.Key.create ("user", Sihl_contract.User.sexp_of_t)
;;

exception User_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No user found");
    Logs.info (fun m -> m "Have you applied the user middleware for this route?");
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

let key_logout : unit Opium.Context.key =
  Opium.Context.Key.create ("user.logout", Sexplib.Std.sexp_of_unit)
;;

let logout res =
  let env = res.Opium.Response.env in
  let env = Opium.Context.add key_logout () env in
  { res with env }
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
        let env = resp.Opium.Response.env in
        (match Opium.Context.find key_logout env with
        | None -> Lwt.return resp
        | Some () ->
          let* () = Sihl_facade.Session.set_value session ~k:key ~v:None in
          Lwt.return resp)
      | None -> handler req)
    | None -> handler req
  in
  Rock.Middleware.create ~name:"user.session" ~filter
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
        let env = resp.Opium.Response.env in
        (match Opium.Context.find key_logout env with
        | None -> Lwt.return resp
        | Some () -> failwith "todo")
      | None -> handler req)
    | None -> handler req
  in
  Rock.Middleware.create ~name:"user.token" ~filter
;;
