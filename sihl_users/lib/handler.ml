open Base

let ( let* ) = Lwt.bind

module Login = struct
  open Sihl_core

  type body_out = { token : string; user_id : string } [@@deriving yojson]

  let handler =
    Http.get "/users/login/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* token = Service.User.token req user in
    let response = { token = Model.Token.value token; user_id = user.id } in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module Register = struct
  open Sihl_core

  type body_in = { email : string; username : string option; password : string }
  [@@deriving yojson]

  let handler =
    Http.post "/users/register/" @@ fun req ->
    let* { email; username; password } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let* _ = Service.User.register req ~email ~username ~password in
    Http.Response.empty |> Lwt.return
end

module GetMe = struct
  open Sihl_core

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.get "/users/users/me/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Http.Response.json
    |> Lwt.return
end

module Logout = struct
  open Sihl_core

  let handler =
    Http.delete "/users/logout/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* () = Service.User.logout req user in
    Http.Response.empty |> Lwt.return
end

module GetUser = struct
  open Sihl_core

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.get "/users/users/:id/" @@ fun req ->
    let user_id = Http.param req "id" in
    let user = Middleware.Authn.authenticate req in
    let* response = Service.User.get req user ~user_id in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module GetUsers = struct
  open Sihl_core

  type body_out = Model.User.t list [@@deriving yojson]

  let handler =
    Http.get "/users/users/" @@ fun req ->
    let user = Middleware.Authn.authenticate req in
    let* response = Service.User.get_all req user in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module UpdatePassword = struct
  open Sihl_core

  type body_in = {
    email : string;
    old_password : string;
    new_password : string;
  }
  [@@deriving yojson]

  let handler =
    Http.post "/users/update-password/" @@ fun req ->
    let* { email; old_password; new_password } =
      Http.require_body_exn req body_in_of_yojson
    in
    let user = Middleware.Authn.authenticate req in
    let* _ =
      Service.User.update_password req user ~email ~old_password ~new_password
    in
    Http.Response.empty |> Lwt.return
end

module UpdateDetails = struct
  open Sihl_core

  type body_in = { email : string; username : string option }
  [@@deriving yojson]

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.post "/users/update-details/" @@ fun req ->
    let* { email; username } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Middleware.Authn.authenticate req in
    let* user = Service.User.update_details req user ~email ~username in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Http.Response.json
    |> Lwt.return
end

module SetPassword = struct
  open Sihl_core

  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    Http.post "/users/set-password/" @@ fun req ->
    let* { user_id; password } = Http.require_body_exn req body_in_of_yojson in
    let user = Middleware.Authn.authenticate req in
    let* _ = Service.User.set_password req user ~user_id ~password in
    Http.Response.empty |> Lwt.return
end

module ConfirmEmail = struct
  open Sihl_core

  let handler =
    Http.get "/users/confirm-email/" @@ fun req ->
    let token = Http.query req "token" in
    let* () = Service.User.confirm_email req token in
    Http.Response.empty |> Lwt.return
end

module RequestPasswordReset = struct
  open Sihl_core

  type body_in = { email : string } [@@deriving yojson]

  let handler =
    Http.post "/users/request-password-reset/" @@ fun req ->
    let* { email } = Http.require_body_exn req body_in_of_yojson in
    let* () = Service.User.request_password_reset req ~email in
    Http.Response.empty |> Lwt.return
end

module ResetPassword = struct
  open Sihl_core

  type body_in = { token : string; new_password : string } [@@deriving yojson]

  let handler =
    Http.post "/users/reset-password/" @@ fun req ->
    let* { token; new_password } =
      Http.require_body_exn req body_in_of_yojson
    in
    let* () = Service.User.reset_password req ~token ~new_password in
    Http.Response.empty |> Lwt.return
end

module AdminUi = struct
  module Dashboard = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.get "/admin/dashboard/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      Admin_ui.dashboard_page user
      |> Admin_ui.render |> Http.Response.html |> Lwt.return
  end

  module Login = struct
    open Sihl_core

    let get =
      Sihl_core.Http.get "/admin/login/" @@ fun _ ->
      Admin_ui.login_page |> Admin_ui.render |> Http.Response.html |> Lwt.return

    let post =
      Sihl_core.Http.post "/admin/login/" @@ fun req ->
      let* body = req |> Opium.Std.Request.body |> Opium.Std.Body.to_string in
      let query = body |> Uri.query_of_encoded in
      let email = query |> Http.find_in_query "email" in
      let password = query |> Http.find_in_query "password" in
      match (email, password) with
      | Some email, Some password ->
          let* token = Service.User.login req ~email ~password in
          (* TODO set success flash message *)
          Http.Response.empty
          |> Http.Response.start_session (Model.Token.value token)
          |> Http.Response.redirect "/admin/dashboard/"
          |> Lwt.return
      | _ ->
          (* TODO set error flash message *)
          Http.Response.empty
          |> Http.Response.redirect "/admin/login/"
          |> Lwt.return
  end

  module Logout = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.post "/admin/logout/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      let* () = Service.User.logout req user in
      Http.Response.empty |> Http.Response.stop_session
      |> Http.Response.redirect "/admin/login/"
      |> Lwt.return
  end

  module Users = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.get "/admin/users/users/" @@ fun req ->
      let user = Middleware.Authn.authenticate req in
      let* users = Service.User.get_all req user in
      Admin_ui.users_page users |> Admin_ui.render |> Http.Response.html
      |> Lwt.return
  end

  module User = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.get "/admin/users/users/:id/" @@ fun req ->
      let user_id = Http.param req "id" in
      let user = Middleware.Authn.authenticate req in
      let* user = Service.User.get req user ~user_id in
      Admin_ui.user_page user |> Admin_ui.render |> Http.Response.html
      |> Lwt.return
  end

  module UserSetPassword = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.post "/admin/users/users/:id/set-password/" @@ fun req ->
      let user_id = Http.param req "id" in
      let user = Middleware.Authn.authenticate req in
      let* body = req |> Opium.Std.Request.body |> Opium.Std.Body.to_string in
      let password =
        body |> Uri.query_of_encoded |> Http.find_in_query "password"
      in
      match password with
      | Some password ->
          Logs.info (fun m -> m "found a new password %s" password);
          let* _ = Service.User.set_password req user ~user_id ~password in
          (* TODO set success flash message *)
          Http.Response.empty
          |> Http.Response.redirect
             @@ [%string "/admin/users/users/$(user_id)/"]
          |> Lwt.return
      | _ ->
          Logs.info (fun m -> m "no password found");
          (* TODO set error flash message *)
          Http.Response.empty
          |> Http.Response.redirect "/admin/login/"
          |> Lwt.return
  end

  module Catch = struct
    open Sihl_core

    let handler =
      Sihl_core.Http.all "/admin/**" @@ fun _ ->
      (* TODO flash error with requested page *)
      Http.Response.empty
      |> Http.Response.redirect "/admin/dashboard/"
      |> Lwt.return
  end
end
