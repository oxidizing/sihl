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
    let* body_in = Sihl_core.Http.require_body_exn req body_in_of_yojson in
    let* _ =
      Service.User.register req ~email:body_in.email ~username:body_in.username
        ~password:body_in.password ~name:body_in.name
    in
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
    let* body_in = Sihl_core.Http.require_body_exn req body_in_of_yojson in
    let user = Service.User.authenticate req in
    let* _ =
      Service.User.update_password req user ~email:body_in.email
        ~old_password:body_in.old_password ~new_password:body_in.new_password
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
    let* body_in = Sihl_core.Http.require_body_exn req body_in_of_yojson in
    let user = Service.User.authenticate req in
    Service.User.update_details req user ~email:body_in.email
      ~username:body_in.username ~name:body_in.name ~phone:body_in.phone
end

module SetPassword = struct
  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    post "/users/set-password/"
    @@ Sihl_core.Http.with_json
    @@ fun req ->
    let* body_in = Sihl_core.Http.require_body_exn req body_in_of_yojson in
    let user = Service.User.authenticate req in
    let* _ =
      Service.User.set_password req user ~user_id:body_in.user_id
        ~password:body_in.password
    in
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

(* module RequestPasswordReset = {
 *   [@decco]
 *   type body_in = {email: string};
 *
 *   [@decco]
 *   type body_out = {message: string};
 *
 *   let endpoint = (root, database) =>
 *     Sihl.App.Http.dbEndpoint({
 *       database,
 *       verb: POST,
 *       path: {j|/$root/request-password-reset/|j},
 *       handler: (conn, req) => {
 *         open! Sihl.App.Http.Endpoint;
 *         let%Async {email} = req.requireBody(body_in_decode);
 *         let%Async _ = Service.User.requestPasswordReset(conn, ~email);
 *         Async.async @@ OkJson(body_out_encode({message: "ok"}));
 *       },
 *     });
 * }; *)

(* module ResetPassword = {
 *   [@decco]
 *   type body_in = {
 *     token: string,
 *     newPassword: string,
 *   };
 *
 *   [@decco]
 *   type body_out = {message: string};
 *
 *   let endpoint = (root, database) =>
 *     Sihl.App.Http.dbEndpoint({
 *       database,
 *       verb: POST,
 *       path: {j|/$root/reset-password/|j},
 *       handler: (conn, req) => {
 *         open! Sihl.App.Http.Endpoint;
 *         let%Async {token, newPassword} = req.requireBody(body_in_decode);
 *         let%Async _ = Service.User.resetPassword(conn, ~token, ~newPassword);
 *         Async.async @@ OkJson(body_out_encode({message: "ok"}));
 *       },
 *     });
 * }; *)

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
  ]

let add_handlers app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes
