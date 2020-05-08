open Base

let ( let* ) = Lwt.bind

module Login = struct
  open Sihl_core.Http

  type body_out = { token : string; user_id : string } [@@deriving yojson]

  let handler =
    get "/users/login/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* token = Service.User.token req user in
    let response = { token = Model.Token.value token; user_id = user.id } in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Response.json
    |> Lwt.return
end

module Register = struct
  open Sihl_core.Http

  type body_in = { email : string; username : string option; password : string }
  [@@deriving yojson]

  let handler =
    post "/users/register/" @@ fun req ->
    let* { email; username; password } =
      require_body_exn req body_in_of_yojson
    in
    let* _ = Service.User.register req ~email ~username ~password in
    Response.empty |> Lwt.return
end

module GetMe = struct
  open Sihl_core.Http

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    get "/users/users/me/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Response.json
    |> Lwt.return
end

module Logout = struct
  open Sihl_core.Http

  let handler =
    delete "/users/logout/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* () = Service.User.logout req user in
    Response.empty |> Lwt.return
end

module GetUser = struct
  open Sihl_core.Http

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    get "/users/users/:id/" @@ fun req ->
    let user_id = param req "id" in
    let user = Middleware.Authn.authenticate req in
    let* response = Service.User.get req user ~user_id in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Response.json
    |> Lwt.return
end

module GetUsers = struct
  open Sihl_core.Http

  type body_out = Model.User.t list [@@deriving yojson]

  let handler =
    get "/users/users/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* response = Service.User.get_all req user in
    response |> body_out_to_yojson |> Yojson.Safe.to_string |> Response.json
    |> Lwt.return
end

module UpdatePassword = struct
  open Sihl_core.Http

  type body_in = {
    email : string;
    old_password : string;
    new_password : string;
  }
  [@@deriving yojson]

  let handler =
    post "/users/update-password/" @@ fun req ->
    let* { email; old_password; new_password } =
      require_body_exn req body_in_of_yojson
    in
    let user = Middleware.Authn.authenticate req in
    let* _ =
      Service.User.update_password req user ~email ~old_password ~new_password
    in
    Response.empty |> Lwt.return
end

module UpdateDetails = struct
  open Sihl_core.Http

  type body_in = { email : string; username : string option }
  [@@deriving yojson]

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    post "/users/update-details/" @@ fun req ->
    let* { email; username } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Middleware.Authn.authenticate req in
    let* user = Service.User.update_details req user ~email ~username in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Response.json
    |> Lwt.return
end

module SetPassword = struct
  open Sihl_core.Http

  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    post "/users/set-password/" @@ fun req ->
    let* { user_id; password } = require_body_exn req body_in_of_yojson in
    let user = Middleware.Authn.authenticate req in
    let* _ = Service.User.set_password req user ~user_id ~password in
    Response.empty |> Lwt.return
end

module ConfirmEmail = struct
  open Sihl_core.Http

  let handler =
    get "/users/confirm-email/" @@ fun req ->
    let token = query req "token" in
    let* () = Service.User.confirm_email req token in
    Response.empty |> Lwt.return
end

module RequestPasswordReset = struct
  open Sihl_core.Http

  type body_in = { email : string } [@@deriving yojson]

  let handler =
    post "/users/request-password-reset/" @@ fun req ->
    let* { email } = require_body_exn req body_in_of_yojson in
    let* () = Service.User.request_password_reset req ~email in
    Response.empty |> Lwt.return
end

module ResetPassword = struct
  open Sihl_core.Http

  type body_in = { token : string; new_password : string } [@@deriving yojson]

  let handler =
    post "/users/reset-password/" @@ fun req ->
    let* { token; new_password } = require_body_exn req body_in_of_yojson in
    let* () = Service.User.reset_password req ~token ~new_password in
    Response.empty |> Lwt.return
end

module AdminUi = struct
  module Dashboard = struct
    open Sihl_core.Http

    let handler =
      get "/admin/dashboard/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      let flash = Sihl_core.Flash.current req in
      Admin_ui.dashboard_page ~flash user
      |> Admin_ui.render |> Response.html |> Lwt.return
  end

  module Login = struct
    open Sihl_core.Http

    let get =
      get "/admin/login/" @@ fun req ->
      let flash = Sihl_core.Flash.current req in
      Admin_ui.login_page ~flash |> Admin_ui.render |> Response.html
      |> Lwt.return

    let post =
      Sihl_core.Http.post "/admin/login/" @@ fun req ->
      let* email, password = url_encoded2 req "email" "password" in
      let* token =
        Sihl_core.Fail.try_to_run (fun () ->
            Service.User.login req ~email ~password)
      in
      match token with
      | Ok token ->
          Response.empty
          |> Response.start_session (Model.Token.value token)
          |> Response.redirect "/admin/dashboard/"
          |> Lwt.return
      | Error _ ->
          Sihl_core.Flash.redirect_with_error req ~path:"/admin/login/"
            "Provided email or password is wrong."
  end

  module Logout = struct
    open Sihl_core.Http

    let handler =
      post "/admin/logout/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      let* () = Service.User.logout req user in
      Response.empty |> Response.stop_session
      |> Response.redirect "/admin/login/"
      |> Lwt.return
  end

  module Users = struct
    open Sihl_core.Http

    let handler =
      get "/admin/users/users/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      let flash = Sihl_core.Flash.current req in
      let* users = Service.User.get_all req user in
      Admin_ui.users_page ~flash users
      |> Admin_ui.render |> Response.html |> Lwt.return
  end

  module User = struct
    open Sihl_core.Http

    let handler =
      get "/admin/users/users/:id/" @@ fun req ->
      let user_id = param req "id" in
      let user = Middleware.Authn.authenticate req in
      let flash = Sihl_core.Flash.current req in
      let* user = Service.User.get req user ~user_id in
      Admin_ui.user_page ~flash user
      |> Admin_ui.render |> Response.html |> Lwt.return
  end

  module UserSetPassword = struct
    open Sihl_core.Http

    let handler =
      post "/admin/users/users/:id/set-password/" @@ fun req ->
      let user_id = param req "id" in
      let user_page = [%string "/admin/users/users/$(user_id)/"] in
      let user = Middleware.Authn.authenticate req in
      let* password = url_encoded req "password" in
      let* result =
        Sihl_core.Fail.try_to_run (fun () ->
            Service.User.set_password req user ~user_id ~password)
      in
      match result with
      | Ok _ ->
          Sihl_core.Flash.redirect_with_success req ~path:user_page
            "New password successfully set"
      | Error error ->
          Logs.err (fun m -> m "%s" (Sihl_core.Fail.Error.show error));
          Sihl_core.Flash.redirect_with_error req ~path:user_page
            (Sihl_core.Fail.Error.show error)
  end

  module Catch = struct
    open Sihl_core.Http

    let handler =
      all "/admin/**" @@ fun req ->
      let path = req |> Opium.Std.Request.uri |> Uri.to_string in
      Sihl_core.Flash.redirect_with_error req ~path:"/admin/dashboard/"
        [%string "Path $(path) not found :("]
  end
end
