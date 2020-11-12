module Core = Sihl_core
module Token = Sihl_token
module User = Sihl_user
module Utils = Sihl_utils
open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"password reset" "sihl.service.password-reset"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let kind = "password_reset"

module TokenData = struct
  type t = { user_id : string } [@@deriving yojson, make, fields]
end

module Make (TokenService : Token.Sig.SERVICE) (UserService : User.Sig.SERVICE) :
  Sig.SERVICE = struct
  let create_reset_token ctx ~email =
    let* user = UserService.find_by_email_opt ctx ~email in
    match user with
    | Some user ->
      let user_id = User.id user in
      let data =
        TokenData.make ~user_id |> TokenData.to_yojson |> Yojson.Safe.to_string
      in
      let* token = TokenService.create ctx ~kind ~data ~expires_in:Utils.Time.OneDay () in
      Lwt.return @@ Some token
    | None ->
      Logs.warn (fun m -> m "PASSWORD_RESET: No user found with email %s" email);
      Lwt.return None
  ;;

  let reset_password ctx ~token ~password ~password_confirmation =
    let* token = TokenService.find_opt ctx token in
    let token = Option.to_result ~none:"Invalid or expired token provided" token in
    let user_id =
      let ( let* ) = Result.bind in
      let* data = Result.map Token.data token in
      let* token = Option.to_result ~none:"Token has not user assigned" data in
      let* parsed = Utils.Json.parse token in
      let* yojson = TokenData.of_yojson parsed in
      Result.ok (TokenData.user_id yojson)
    in
    match user_id with
    | Error msg -> Lwt.return @@ Error msg
    | Ok user_id ->
      let* user = UserService.find ctx ~user_id in
      let* result =
        UserService.set_password ctx ~user ~password ~password_confirmation ()
      in
      Lwt.return @@ Result.map (fun _ -> ()) result
  ;;

  let start ctx = Lwt.return ctx
  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "password-reset"
      ~start
      ~stop
      ~dependencies:[ TokenService.lifecycle; UserService.lifecycle ]
  ;;

  let register () = Core.Container.Service.create lifecycle
end
