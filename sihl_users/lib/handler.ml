open Core
open Opium.Std

let ( let* ) = Lwt.bind

module Login = struct
  open Sihl_core

  type body_out = { token : string } [@@deriving yojson]

  let handler =
    get "/users/login/"
    @@ Http.with_json ~encode:body_out_to_yojson
    @@ fun req ->
    let user = Service.User.authenticate req in
    let* token = Service.User.token req user in
    Lwt.return @@ { token = Model.Token.value token }
end

module Register = struct
  type body_in = {
    email : string;
    username : string;
    password : string;
    name : string;
  }
  [@@deriving yojson]

  let handler =
    post "/users/register/" @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* { email; username; password; name } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let* _ = Service.User.register req ~email ~username ~password ~name in
    Lwt.return @@ ()
end

module GetMe = struct
  open Sihl_core

  let handler =
    get "/users/users/me/"
    @@ Http.with_json ~encode:Model.User.to_yojson
    @@ fun req -> Lwt.return @@ Service.User.authenticate req
end

module Logout = struct
  open Sihl_core

  let handler =
    delete "/users/logout/" @@ Http.with_json
    @@ fun req ->
    let user = Service.User.authenticate req in
    Service.User.logout req user
end

module GetUser = struct
  open Sihl_core

  let handler =
    get "/users/users/:id/" @@ Http.with_json
    @@ fun req ->
    let user_id = Http.param req "id" in
    let user = Service.User.authenticate req in
    Service.User.get req user ~user_id
end

module GetUsers = struct
  open Sihl_core

  type body_out = Model.User.t list [@@deriving yojson]

  let handler =
    get "/users/users/"
    @@ Http.with_json ~encode:body_out_to_yojson
    @@ fun req ->
    let user = Service.User.authenticate req in
    Service.User.get_all req user
end

module UpdatePassword = struct
  type body_in = {
    email : string;
    old_password : string;
    new_password : string;
  }
  [@@deriving yojson]

  let handler =
    post "/users/update-password/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* { email; old_password; new_password } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Service.User.authenticate req in
    let* _ =
      Service.User.update_password req user ~email ~old_password ~new_password
    in
    Lwt.return @@ ()
end

module UpdateDetails = struct
  type body_in = {
    email : string;
    username : string;
    name : string;
    phone : string option;
  }
  [@@deriving yojson]

  let handler =
    post "/users/update-details/"
    @@ Sihl_core.Http.with_json ~encode:Model.User.to_yojson
    @@ fun req ->
    let* { email; username; name; phone } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Service.User.authenticate req in
    Service.User.update_details req user ~email ~username ~name ~phone
end

module SetPassword = struct
  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    post "/users/set-password/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* { user_id; password } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Service.User.authenticate req in
    let* _ = Service.User.set_password req user ~user_id ~password in
    Lwt.return @@ ()
end

module ConfirmEmail = struct
  open Sihl_core

  let handler =
    get "/users/confirm-email/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let token = Http.query req "token" in
    Service.User.confirm_email req token
end

module RequestPasswordReset = struct
  type body_in = { email : string } [@@deriving yojson]

  let handler =
    post "/users/request-password-reset/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* { email } = Sihl_core.Http.require_body_exn req body_in_of_yojson in
    Service.User.request_password_reset req ~email
end

module ResetPassword = struct
  type body_in = { token : string; new_password : string } [@@deriving yojson]

  let handler =
    post "/users/reset-password/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* { token; new_password } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    Service.User.reset_password req ~token ~new_password
end

let routes =
  [
    Login.handler;
    Register.handler;
    Logout.handler;
    GetUser.handler;
    GetUsers.handler;
    GetMe.handler;
    UpdatePassword.handler;
    UpdateDetails.handler;
    SetPassword.handler;
    ConfirmEmail.handler;
    RequestPasswordReset.handler;
    ResetPassword.handler;
  ]

let add_handlers app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes