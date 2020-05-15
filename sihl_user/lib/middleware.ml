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
        Sihl.Err.raise_not_authenticated
          "no user found, have you applied authentication middlewares?"

  let session () app =
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

  let token () app =
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
