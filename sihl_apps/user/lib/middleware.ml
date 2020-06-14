open Base
open Opium.Std

let ( let* ) = Lwt.bind

module Authn = struct
  type user = Sihl.User.t

  let key : user Opium.Hmap.key =
    Opium.Hmap.Key.create ("users.user", [%sexp_of: Sihl.User.t])

  let user req = Opium.Hmap.find key (Request.env req)

  let authenticate request =
    match request |> user with
    | Some user -> user
    | None ->
        Sihl.Core.Err.raise_not_authenticated
          "No user found, have you applied the authentication middleware?"

  let session () =
    let filter handler req =
      match Opium.Hmap.find key (Request.env req) with
      (* user has been authenticated somewhere else already, nothing to do *)
      | Some _ -> handler req
      | None -> (
          let* user_id = Sihl.Http.Session.get "users.id" req in
          match user_id with
          (* there is no user_id, nothing to do *)
          | None -> handler req
          | Some user_id ->
              let* user = Service.User.get req Sihl.User.system ~user_id in
              let env = Opium.Hmap.add key user (Request.env req) in
              let req = { req with Request.env } in
              handler req )
    in
    Rock.Middleware.create ~name:"users.session" ~filter

  let create_session req user =
    Sihl.Http.Session.set ~key:"users.id" ~value:(Sihl.User.id user) req

  let token () =
    let filter handler req =
      match req |> Request.headers |> Cohttp.Header.get_authorization with
      | None -> handler req
      | Some (`Other token) ->
          (* TODO use more robust bearer token parsing *)
          let token =
            token |> String.split ~on:' ' |> List.tl_exn |> List.hd_exn
          in
          let* user = Service.User.get_by_token req token in
          let env = Opium.Hmap.add key user (Request.env req) in
          let req = { req with Request.env } in
          handler req
      | Some (`Basic (email, password)) ->
          let* user =
            Service.User.authenticate_credentials req ~email ~password
          in
          let env = Opium.Hmap.add key user (Request.env req) in
          let req = { req with Request.env } in
          handler req
    in
    Rock.Middleware.create ~name:"users.token" ~filter
end
