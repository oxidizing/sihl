open Base
open Lwt.Syntax

let kind = "password_reset"

module TokenData = struct
  type t = { user_id : string } [@@deriving yojson, make, fields]
end

module Make (TokenService : Token.Sig.SERVICE) (UserService : User_sig.SERVICE) :
  User_password_reset_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "password-reset"
      ~dependencies:[ TokenService.lifecycle; UserService.lifecycle ]
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

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
          TokenService.create ctx ~kind ~data ~expires_in:Utils.Time.OneDay ()
        in
        Lwt.return @@ Some token
    | None ->
        Logs.warn (fun m ->
            m "PASSWORD_RESET: No user found with email %s" email);
        Lwt.return None

  let reset_password ctx ~token ~password ~password_confirmation =
    let* token = TokenService.find_opt ctx token in
    let token =
      Result.of_option ~error:"Invalid or expired token provided" token
    in
    let user_id =
      token |> Result.map ~f:Token.data
      |> Result.bind ~f:(Result.of_option ~error:"Token has not user assigned")
      |> Result.bind ~f:Utils.Json.parse
      |> Result.bind ~f:TokenData.of_yojson
      |> Result.map ~f:TokenData.user_id
    in
    match user_id with
    | Error msg -> Lwt.return @@ Error msg
    | Ok user_id -> (
        let* user = UserService.get ctx ~user_id in
        match user with
        | None ->
            Lwt.return
            @@ Error (Printf.sprintf "User with id %s not found" user_id)
        | Some user ->
            let* result =
              UserService.set_password ctx ~user ~password
                ~password_confirmation ()
            in
            Lwt.return @@ Result.map ~f:(fun _ -> ()) result )
end
