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

let routes =
  [
    Login.handler;
    Register.handler;
    Logout.handler;
    GetUser.handler;
    GetUsers.handler;
    GetMe.handler;
  ]

let add_handlers app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes
