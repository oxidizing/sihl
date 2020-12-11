open Lwt.Syntax
module Core = Sihl_core
module Token = Sihl_contract.Token
module TokenData = Sihl_contract.Token.Data
module User = Sihl_contract.User

let log_src = Logs.Src.create "sihl.service.password-reset"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let kind = "password_reset"

let create_reset_token ~email =
  let* user = Sihl_facade.User.find_by_email_opt ~email in
  match user with
  | Some user ->
    let user_id = User.id user in
    let data = TokenData.make ~user_id |> TokenData.to_yojson |> Yojson.Safe.to_string in
    let* token =
      Sihl_facade.Token.create ~kind ~data ~expires_in:Sihl_core.Time.OneDay ()
    in
    Lwt.return @@ Some token
  | None ->
    Logs.warn (fun m -> m "PASSWORD_RESET: No user found with email %s" email);
    Lwt.return None
;;

let reset_password ~token ~password ~password_confirmation =
  let* token = Sihl_facade.Token.find_opt token in
  let token = Option.to_result ~none:"Invalid or expired token provided" token in
  let user_id =
    let ( let* ) = Result.bind in
    let* data = Result.map Token.data token in
    let* token = Option.to_result ~none:"Token has not user assigned" data in
    let* parsed = Sihl_core.Utils.Json.parse token in
    let* yojson = TokenData.of_yojson parsed in
    Result.ok (TokenData.user_id yojson)
  in
  match user_id with
  | Error msg -> Lwt.return @@ Error msg
  | Ok user_id ->
    let* user = Sihl_facade.User.find ~user_id in
    let* result =
      Sihl_facade.User.set_password ~user ~password ~password_confirmation ()
    in
    Lwt.return @@ Result.map (fun _ -> ()) result
;;

let start () = Lwt.return ()
let stop () = Lwt.return ()

let lifecycle =
  Core.Container.Lifecycle.create "password-reset" ~start ~stop ~dependencies:(fun () ->
      [ Sihl_facade.Token.lifecycle (); Sihl_facade.User.lifecycle () ])
;;

let register () = Core.Container.Service.create lifecycle
