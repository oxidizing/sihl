open Base
open Lwt.Syntax
module Sig = User_password_reset_service_sig

let kind = "password_reset"

module TokenData = struct
  type t = { user_id : string } [@@deriving yojson, make, fields]
end

module Make
    (Log : Log.Service.Sig.SERVICE)
    (TokenService : Token.Service.Sig.SERVICE)
    (UserService : User_service_sig.SERVICE) : Sig.SERVICE = struct
  let create_reset_token ctx ~email =
    let* user = UserService.find_by_email_opt ctx ~email in
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
        Log.warn (fun m ->
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
    | Ok user_id ->
        let* user = UserService.find ctx ~user_id in
        let* result =
          UserService.set_password ctx ~user ~password ~password_confirmation ()
        in
        Lwt.return @@ Result.map ~f:(fun _ -> ()) result

  let start ctx = Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.make "password-reset" ~start ~stop
      ~dependencies:
        [ Log.lifecycle; TokenService.lifecycle; UserService.lifecycle ]
end
