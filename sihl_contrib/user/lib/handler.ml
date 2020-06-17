open Base

let ( let* ) = Lwt_result.bind

module Login = struct
  open Sihl.Http

  type body_out = { token : string; user_id : string } [@@deriving yojson]

  let handler =
    get "/users/login/" @@ fun req ->
    let user = Sihl.Authn.authenticate req in
    let* token = Service.User.token req user in
    let response =
      { token = Model.Token.value token; user_id = Sihl.User.id user }
    in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
    |> Result.return |> Lwt.return
end

module Register = struct
  open Sihl.Http

  type body_in = { email : string; username : string option; password : string }
  [@@deriving yojson]

  let handler =
    post "/users/register/" @@ fun req ->
    let* { email; username; password } =
      Req.require_body req body_in_of_yojson
    in
    let* _ = Service.User.register req ~email ~username ~password in
    Res.empty |> Result.return |> Lwt.return
end

module GetMe = struct
  open Sihl.Http

  type body_out = Sihl.User.t [@@deriving yojson]

  let handler =
    get "/users/users/me/" @@ fun req ->
    let user = Sihl.Authn.authenticate req in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
    |> Result.return |> Lwt.return
end

module Logout = struct
  open Sihl.Http

  let handler =
    delete "/users/logout/" @@ fun req ->
    let user = Sihl.Authn.authenticate req in
    let* () = Service.User.logout req user in
    Res.empty |> Result.return |> Lwt.return
end

module GetUser = struct
  open Sihl.Http

  type body_out = Sihl.User.t [@@deriving yojson]

  let handler =
    get "/users/users/:id/" @@ fun req ->
    let user_id = Req.param req "id" in
    let user = Sihl.Authn.authenticate req in
    let* response = Service.User.get req user ~user_id in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
    |> Result.return |> Lwt.return
end

module GetUsers = struct
  open Sihl.Http

  type body_out = Sihl.User.t list [@@deriving yojson]

  let handler =
    get "/users/users/" @@ fun req ->
    let user = Sihl.Authn.authenticate req in
    let* response = Service.User.get_all req user in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
    |> Result.return |> Lwt.return
end

module UpdatePassword = struct
  open Sihl.Http

  type body_in = {
    email : string;
    old_password : string;
    new_password : string;
  }
  [@@deriving yojson]

  let handler =
    post "/users/update-password/" @@ fun req ->
    let* { email; old_password; new_password } =
      Req.require_body req body_in_of_yojson
    in
    let user = Sihl.Authn.authenticate req in
    let* _ =
      Service.User.update_password req user ~email ~old_password ~new_password
    in
    Res.empty |> Result.return |> Lwt.return
end

module UpdateDetails = struct
  open Sihl.Http

  type body_in = { email : string; username : string option }
  [@@deriving yojson]

  type body_out = Sihl.User.t [@@deriving yojson]

  let handler =
    post "/users/update-details/" @@ fun req ->
    let* { email; username } = Req.require_body req body_in_of_yojson in
    let user = Sihl.Authn.authenticate req in
    let* user = Service.User.update_details req user ~email ~username in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
    |> Result.return |> Lwt.return
end

module SetPassword = struct
  open Sihl.Http

  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    post "/users/set-password/" @@ fun req ->
    let* { user_id; password } = Req.require_body req body_in_of_yojson in
    let user = Sihl.Authn.authenticate req in
    let* _ = Service.User.set_password req user ~user_id ~password in
    Res.empty |> Result.return |> Lwt.return
end

module ConfirmEmail = struct
  open Sihl.Http

  let handler =
    get "/users/confirm-email/" @@ fun req ->
    let token = Req.query req "token" in
    let* () = Service.User.confirm_email req token in
    Res.empty |> Result.return |> Lwt.return
end

module RequestPasswordReset = struct
  open Sihl.Http

  type body_in = { email : string } [@@deriving yojson]

  let handler =
    post "/users/request-password-reset/" @@ fun req ->
    let* { email } = Req.require_body req body_in_of_yojson in
    let* () = Service.User.request_password_reset req ~email in
    Res.empty |> Result.return |> Lwt.return
end

module ResetPassword = struct
  open Sihl.Http

  type body_in = { token : string; new_password : string } [@@deriving yojson]

  let handler =
    post "/users/reset-password/" @@ fun req ->
    let* { token; new_password } = Req.require_body req body_in_of_yojson in
    let* () = Service.User.reset_password req ~token ~new_password in
    Res.empty |> Result.return |> Lwt.return
end

module AdminUi = struct
  module Login = struct
    let get =
      Sihl.Http.get "/admin/login/" @@ fun req ->
      let* flash = Sihl.Middleware.Flash.current req in
      let ctx = Sihl.Template.context ~flash () in
      Sihl.Admin.render ctx Sihl.Admin.Component.LoginPage.createElement ()
      |> Sihl.Http.Res.html |> Result.return |> Lwt.return

    let post =
      Sihl.Http.post "/admin/login/" @@ fun req ->
      let* email, password =
        Sihl.Http.Req.url_encoded2 req "email" "password"
      in
      let* user = Service.User.authenticate_credentials req ~email ~password in
      let* () = Middleware.Authn.create_session req user in
      Sihl.Http.Res.empty
      |> Sihl.Http.Res.redirect "/admin/dashboard/"
      |> Result.return |> Lwt.return
  end

  module Logout = struct
    open Sihl.Http

    let handler =
      post "/admin/logout/" @@ fun req ->
      let user = Sihl.Authn.authenticate req in
      let* () = Service.User.logout req user in
      Res.empty |> Res.stop_session
      |> Res.redirect "/admin/login/"
      |> Result.return |> Lwt.return
  end

  module Users = struct
    open Sihl.Http

    let handler =
      get "/admin/users/users/" @@ fun req ->
      let user = Sihl.Authn.authenticate req in
      let* flash = Sihl.Middleware.Flash.current req in
      let ctx = Sihl.Template.context ~flash () in
      let* users = Service.User.get_all req user in
      Sihl.Admin.render ctx Admin_component_user.UserListPage.createElement
        users
      |> Res.html |> Result.return |> Lwt.return
  end

  module User = struct
    open Sihl.Http

    let handler =
      get "/admin/users/users/:id/" @@ fun req ->
      let user_id = Req.param req "id" in
      let user = Sihl.Authn.authenticate req in
      let* flash = Sihl.Middleware.Flash.current req in
      let ctx = Sihl.Template.context ~flash () in
      let* user = Service.User.get req user ~user_id in
      Sihl.Admin.render ctx Admin_component_user.UserPage.createElement user
      |> Res.html |> Result.return |> Lwt.return
  end

  module UserSetPassword = struct
    open Sihl.Http

    let handler =
      post "/admin/users/users/:id/set-password/" @@ fun req ->
      let user_id = Req.param req "id" in
      let user_page = Printf.sprintf "/admin/users/users/%s/" user_id in
      let user = Sihl.Authn.authenticate req in
      let* password = Req.url_encoded req "password" in
      Lwt.bind (Service.User.set_password req user ~user_id ~password)
        (fun result ->
          match result with
          | Ok _ ->
              Sihl.Middleware.Flash.redirect_with_success req ~path:user_page
                "New password successfully set"
          | Error error ->
              Logs.err (fun m -> m "%s" (Sihl.Error.show error));
              Sihl.Middleware.Flash.redirect_with_error req ~path:user_page
                (Sihl.Error.show error))
  end
end
