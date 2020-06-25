open Base
open Opium.Std

let ( let* ) = Lwt.bind

module Authn = struct
  type user = Sihl.User.t

  let key : user Opium.Hmap.key =
    Opium.Hmap.Key.create ("users.user", [%sexp_of: Sihl.User.t])

  let user req = Opium.Hmap.find key (Request.env req)

  let authenticate _ = failwith "TODO implement authenticate in middleware.ml"

  (* match request |> user with
   * | Some user -> user
   * | None ->
   *     Sihl.Core.Err.raise_not_authenticated
   *       "No user found, have you applied the authentication middleware?" *)

  let session () =
    let filter handler req =
      let ctx = Sihl.Http.ctx req in
      match Opium.Hmap.find key (Request.env req) with
      (* user has been authenticated somewhere else already, nothing to do *)
      | Some _ -> handler req
      | None -> (
          let* user_id =
            Sihl.Session.get_value ~key:"users.id" ctx
            |> Lwt_result.map_err Sihl.Core.Err.raise_server
            |> Lwt.map Result.ok_exn
          in
          match user_id with
          (* there is no user_id, nothing to do *)
          | None -> handler req
          | Some user_id -> (
              let* user =
                Sihl.User.get ctx ~user_id
                |> Lwt_result.map_err Sihl.Core.Err.raise_not_authenticated
                |> Lwt.map Result.ok_exn
              in
              match user with
              | None -> Sihl.Core.Err.raise_not_authenticated "No user found"
              | Some user ->
                  let env = Opium.Hmap.add key user (Request.env req) in
                  let req = { req with Request.env } in
                  handler req ) )
    in
    Rock.Middleware.create ~name:"users.session" ~filter

  let create_session req user =
    Sihl.Session.set_value req ~key:"users.id" ~value:(Sihl.User.id user)
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn

  let token () =
    let filter handler req =
      let ctx = Sihl.Http.ctx req in
      match req |> Request.headers |> Cohttp.Header.get_authorization with
      | None -> handler req
      | Some (`Other token) -> (
          (* TODO use more robust bearer token parsing *)
          let token =
            token |> String.split ~on:' ' |> List.tl_exn |> List.hd_exn
          in
          let (module UserService : Sihl.User.Sig.SERVICE) =
            Sihl.Container.fetch_service_exn Sihl.User.Sig.key
          in
          let* user =
            UserService.get_by_token ctx token
            |> Lwt_result.map_err Sihl.Core.Err.raise_not_authenticated
            |> Lwt.map Result.ok_exn
          in
          match user with
          | None -> Sihl.Core.Err.raise_not_authenticated "No user found"
          | Some user ->
              let env = Opium.Hmap.add key user (Request.env req) in
              let req = { req with Request.env } in
              handler req )
      | Some (`Basic (email, password)) ->
          let (module UserService : Sihl.User.Sig.SERVICE) =
            Sihl.Container.fetch_service_exn Sihl.User.Sig.key
          in
          let* user =
            UserService.authenticate_credentials ctx ~email ~password
            |> Lwt_result.map_err Sihl.Core.Err.raise_not_authenticated
            |> Lwt.map Result.ok_exn
          in
          let env = Opium.Hmap.add key user (Request.env req) in
          let req = { req with Request.env } in
          handler req
    in
    Rock.Middleware.create ~name:"users.token" ~filter
end
