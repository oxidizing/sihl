open Base

let ( let* ) = Lwt_result.bind

let kind = "password_reset"

module TokenData = struct
  type t = { user_id : string } [@@deriving yojson, make, fields]
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
            m "PASSWORD_RESET: No user found with email %s" email);
        Lwt_result.return None

  let reset_password ctx ~token ~password ~password_confirmation =
    let* token = TokenService.find_opt ctx ~value:token () in
    let token =
      Result.of_option ~error:"Invalid or expired token provided" token
    in
    let user_id =
      token |> Result.map ~f:Token.data
      |> Result.bind ~f:Utils.Json.parse
      |> Result.bind ~f:TokenData.of_yojson
      |> Result.map ~f:TokenData.user_id
    in
    match user_id with
    | Error msg -> Lwt_result.return @@ Error msg
    | Ok user_id -> (
        let* user = UserService.get ctx ~user_id in
        match user with
        | None ->
            Lwt_result.return
            @@ Error (Printf.sprintf "User with id %s not found" user_id)
        | Some user ->
            let* _ =
              UserService.set_password ctx ~user ~password
                ~password_confirmation ()
            in
            Lwt_result.return @@ Ok () )
end
