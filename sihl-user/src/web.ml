let user_from_token find_user ?(key = "user_id") read_token req
    : Sihl.Contract.User.t option Lwt.t
  =
  match Sihl.Web.Request.bearer_token req with
  | Some token ->
    let%lwt user_id = read_token token ~k:key in
    (match user_id with
    | None -> Lwt.return None
    | Some user_id -> find_user user_id)
  | None -> Lwt.return None
;;

let user_from_session find_user ?cookie_key ?secret ?(key = "user_id") req
    : Sihl.Contract.User.t option Lwt.t
  =
  match Sihl.Web.Session.find ?cookie_key ?secret key req with
  | Some user_id -> find_user user_id
  | None -> Lwt.return None
;;
