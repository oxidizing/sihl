open Base
open Opium.Std

let ( let* ) = Lwt.bind

module Authn = struct
  module Env = struct
    type user' = Model.User.t

    let key : user' Opium.Hmap.key =
      Opium.Hmap.Key.create ("user", [%sexp_of: Model.User.t])
  end

  let user req = Opium.Hmap.find Env.key (Request.env req)

  let authenticate request =
    match request |> user with
    | Some user -> user
    | None ->
        Sihl_core.Fail.raise_not_authenticated
          "no user found, have you applied authentication middlewares?"

  let session_m app =
    let filter handler req =
      match Opium.Hmap.find Env.key (Request.env req) with
      (* user has been authenticated somewhere else already, nothing to do *)
      | Some _ -> handler req
      | None -> (
          let token = Cookie.get req ~key:"session_id" in
          match token with
          (* there is no session cookie, nothing to do *)
          | None -> handler req
          | Some token ->
              let* user = Service.User.get_by_token req token in
              let env = Opium.Hmap.add Env.key user (Request.env req) in
              let req = { req with Request.env } in
              handler req )
    in
    let m = Rock.Middleware.create ~name:"http session authn" ~filter in
    middleware m app

  let token_m app =
    let filter handler req =
      match req |> Request.headers |> Cohttp.Header.get_authorization with
      | None -> handler req
      | Some (`Other token) ->
          (* TODO use more robust bearer token parsing *)
          let token =
            token |> String.split ~on:' ' |> List.tl_exn |> List.hd_exn
          in
          let* user = Service.User.get_by_token req token in
          let env = Opium.Hmap.add Env.key user (Request.env req) in
          let req = { req with Request.env } in
          handler req
      | Some (`Basic (email, password)) ->
          let* user =
            Service.User.authenticate_credentials req ~email ~password
          in
          let env = Opium.Hmap.add Env.key user (Request.env req) in
          let req = { req with Request.env } in
          handler req
    in
    let m = Rock.Middleware.create ~name:"http token authn" ~filter in
    middleware m app
end

module Flash = struct
  (* TODO implement flash
     if accept is not text/html, do nothing (so json API doesn't care)
     a. request comes in and flash cookie is not set
     a1. create and store token
     a2. create and store flash {token: string; color: string; text: string} in memory
     a3. create flash cookie with token
     a4. set Set-Cookie header
     b. request comes in a flash cookie is set, there is no next flash stored
     b1. if there is a current flash, remove it
     c. request comes in and flash cookie is set, there is a next flash stored
     c1. set current flash to next flash, set next flash to empty
  *)
end
