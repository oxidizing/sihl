open Base
open Opium.Std

let ( let* ) = Lwt.bind

let key : User.t Opium.Hmap.key =
  Opium.Hmap.Key.create ("users.user", [%sexp_of: User.t])

let session () =
  let filter handler req =
    let ctx = Web_req.ctx_of req in
    match Opium.Hmap.find key (Request.env req) with
    (* user has been authenticated somewhere else already, nothing to do *)
    | Some _ -> handler req
    | None -> (
        let* user_id =
          Session.get_value ~key:"users.id" ctx |> Lwt.map Result.ok_or_failwith
        in
        match user_id with
        (* there is no user_id, nothing to do *)
        | None -> handler req
        | Some user_id -> (
            let* user =
              User.get ctx ~user_id |> Lwt.map Result.ok_or_failwith
            in
            match user with
            | None -> failwith "No user found"
            | Some user ->
                let env = Opium.Hmap.add key user (Request.env req) in
                let req = { req with Request.env } in
                handler req ) )
  in
  Rock.Middleware.create ~name:"users.session" ~filter

(* let token () =
 *   let filter handler req =
 *     let ctx = Http.ctx req in
 *     match req |> Request.headers |> Cohttp.Header.get_authorization with
 *     | None -> handler req
 *     | Some (`Other token) -> (
 *         (\* TODO use more robust bearer token parsing *\)
 *         let token =
 *           token |> String.split ~on:' ' |> List.tl_exn |> List.hd_exn
 *         in
 *         let (module UserService : User.Sig.SERVICE) =
 *           Core.Container.fetch_service_exn User.Sig.key
 *         in
 *         let* user =
 *           UserService.get_by_token ctx token
 *           |> Lwt_result.map_err Core.Err.raise_not_authenticated
 *           |> Lwt.map Result.ok_exn
 *         in
 *         match user with
 *         | None -> Core.Err.raise_not_authenticated "No user found"
 *         | Some user ->
 *             let env = Opium.Hmap.add key user (Request.env req) in
 *             let req = { req with Request.env } in
 *             handler req )
 *     | Some (`Basic (email, password)) ->
 *         let (module UserService : User.Sig.SERVICE) =
 *           Core.Container.fetch_service_exn User.Sig.key
 *         in
 *         let* user =
 *           UserService.authenticate_credentials ctx ~email ~password
 *           |> Lwt_result.map_err Core.Err.raise_not_authenticated
 *           |> Lwt.map Result.ok_exn
 *         in
 *         let env = Opium.Hmap.add key user (Request.env req) in
 *         let req = { req with Request.env } in
 *         handler req
 *   in
 *   Rock.Middleware.create ~name:"users.token" ~filter *)
