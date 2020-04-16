open! Core

let ( let* ) = Lwt.bind

module User = struct
  let authenticate request =
    request |> Middleware.Authentication.user
    |> Sihl_core.Http.failwith_opt "no user provided"

  let register request ~email ~password ~username ~name =
    let* user = Repository.User.get_by_email request ~email in
    if Result.is_ok user then
      Sihl_core.Fail.raise_bad_request "email already taken"
    else
      let user = Model.User.create ~email ~password ~username ~name in
      let* op_result = Repository.User.insert request user in
      let () =
        op_result |> Sihl_core.Fail.with_database "could not insert user"
      in
      Lwt.return user

  let logout user request =
    let id = Model.User.id user in
    Repository.Token.delete_by_user request ~id

  let login request ~email ~password =
    let* user = Repository.User.get_by_email request ~email in
    let user = user |> Sihl_core.Fail.with_database "could not fetch user" in
    if Model.User.matches_password password user then
      let token = Model.Token.create user in
      let* result = Repository.Token.insert request token in
      let () =
        result |> Sihl_core.Fail.with_database "could not insert token"
      in
      Lwt.return token
    else Sihl_core.Fail.raise_not_authenticated "wrong credentials provided"

  let token request user =
    let token = Model.Token.create user in
    let* result = Repository.Token.insert request token in
    let () = result |> Sihl_core.Fail.with_database "failed to store token" in
    Lwt.return token

  let get request user ~user_id =
    if Model.User.is_admin user || Model.User.is_owner user user_id then
      let* user = Repository.User.get request ~id:user_id in
      user
      |> Sihl_core.Fail.with_bad_request
           ("could not find user with id " ^ user_id)
      |> Lwt.return
    else Sihl_core.Fail.raise_no_permissions "user is not allowed to fetch user"

  let get_all request user =
    if Model.User.is_admin user then
      let* users = Repository.User.get_all request in
      users
      |> Sihl_core.Fail.with_database "could not fetch all users"
      |> Lwt.return
    else
      Sihl_core.Fail.raise_no_permissions
        "user is not allowed to fetch all users"
end

module Middleware = Middleware
