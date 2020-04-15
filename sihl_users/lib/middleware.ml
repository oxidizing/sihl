module Authentication = struct
  open Opium.Std

  (* My convention is to stick the keys inside an Env sub module. By not exposing
     this module in the mli we are preventing the user or other middleware from
     meddling with our values by not using our interface *)
  module Env = struct
    (* or use type nonrec *)
    type user' = Model.User.t

    let key : user' Opium.Hmap.key =
      Opium.Hmap.Key.create ("user", [%sexp_of: Model.User.t])
  end

  let authenticate_token request token =
    let open Lwt_result.Infix in
    let result =
      Repository.Token.get request ~value:token >>= fun token ->
      let token_user = Model.Token.token_user token in
      Repository.User.get request ~id:token_user
    in
    result |> Lwt_result.map_err (fun _ -> "Not authorized")

  let authenticate_credentials request ~email ~password =
    let open Lwt_result.Infix in
    Repository.User.get_by_email request ~email >>= fun user ->
    if Model.User.matches_password user password then
      Lwt_result.ok @@ Lwt.return user
    else Lwt_result.fail "Invalid password or email provided"

  (* Usually middleware gets its own module so the middleware constructor function
     is usually shortened to m. For example, [Auth.m] is obvious enough.
     The auth param (auth : username:string -> password:string -> user option)
     would represent our database model. E.g. it would do some lookup in the db
     and fetch the user. *)
  let m =
    let filter handler req =
      let open Lwt.Infix in
      match req |> Request.headers |> Cohttp.Header.get_authorization with
      | None -> handler req
      | Some (`Other token) -> (
          authenticate_token req token >>= fun result ->
          match result with
          | Ok user ->
              let env = Opium.Hmap.add Env.key user (Request.env req) in
              let req = { req with Request.env } in
              handler req
          (* TODO error handling *)
          | Error _ -> failwith "TODO: bad username/password pair" )
      | Some (`Basic (email, password)) -> (
          authenticate_credentials req ~email ~password >>= fun result ->
          match result with
          | Ok user ->
              let env = Opium.Hmap.add Env.key user (Request.env req) in
              let req = { req with Request.env } in
              handler req
          (* TODO error handling *)
          | Error _ -> failwith "TODO: bad username/password pair" )
    in
    Rock.Middleware.create ~name:"http auth" ~filter

  let user req = Opium.Hmap.find Env.key (Request.env req)
end
