open Base

let ( let* ) = Lwt_result.bind

let kind = "password_reset"

module TokenData = struct
  type t = { user_id : string } [@@deriving yojson, make]
end

module Make (TokenService : Token.Sig.SERVICE) (UserService : User_sig.SERVICE) :
  User_password_reset_sig.SERVICE = struct
  let on_init _ = Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let create_reset_token ctx ~email =
    let* user = UserService.get_by_email ctx ~email in
    match user with
    | Some user ->
        let user_id = User_core.User.id user in
        let data =
          TokenData.make ~user_id |> TokenData.to_yojson
          |> Yojson.Safe.to_string
        in
        let* token =
          TokenService.create ctx ~kind ~data ~expires_in:Utils.Time.OneDay
        in
        Lwt_result.return @@ Some token
    | None ->
        Logs.warn (fun m ->
            m "PASSWORDRESET: No user found with email %s" email);
        Lwt_result.return None

  let reset_password _ _ ~password:_ = failwith "TODO"
end
