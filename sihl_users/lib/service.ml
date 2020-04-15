open! Core
open Lwt_result.Infix

module User = struct
  let authenticate request =
    request |> Middleware.Authentication.user
    |> Sihl_core.Http.failwith_opt "No user provided"

  let register request ~email ~password ~username ~name =
    Repository.User.get_by_email request ~email
    |> Lwt_result.map_err (fun _ -> "Email already taken")
    |> Lwt_result.map (fun _ ->
           Model.User.create ~email ~password ~username ~name)
    >>= fun user ->
    Repository.User.insert request user |> Lwt_result.map (fun _ -> user)

  let logout user request =
    let id = Model.User.id user in
    Repository.Token.delete_by_user request ~id

  let login request ~email ~password =
    Repository.User.get_by_email request ~email >>= fun user ->
    if Model.User.matches_password user password then
      let token = Model.Token.create user in
      Repository.Token.insert request token |> Lwt_result.map (fun _ -> token)
    else Lwt_result.fail "Invalid password or email provided"

  let token request user =
    let token = Model.Token.create user in
    Repository.Token.insert request token |> Lwt_result.map (fun _ -> token)

  let get request user ~userId =
    if Model.User.is_admin user || Model.User.is_owner user userId then
      Repository.User.get request ~id:userId
    else Lwt_result.fail "Not allowed"

  let get_all request user =
    if Model.User.is_admin user then Repository.User.get_all request
    else Lwt_result.fail "Not allowed"
end

module Middleware = Middleware
