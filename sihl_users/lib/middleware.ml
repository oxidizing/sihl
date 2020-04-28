open Opium.Std

let ( let* ) = Lwt_result.bind

module Authentication = struct
  module Env = struct
    type user' = Model.User.t

    let key : user' Opium.Hmap.key =
      Opium.Hmap.Key.create ("user", [%sexp_of: Model.User.t])
  end

  let authenticate_token request token =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    let _ = Logs_lwt.info (fun m -> m "fetch token %s" token) in
    let* token =
      Repository.Token.get ~value:token |> Sihl_core.Db.query_db request
    in
    let _ = Logs_lwt.info (fun m -> m "got token with id  %s" token.id) in
    let token_user = Model.Token.user token in
    let _ =
      Logs_lwt.info (fun m -> m "try to fetch user with id %s" token_user)
    in
    Repository.User.get ~id:token_user
    |> Sihl_core.Db.query_db request
    |> Lwt_result.map_err (fun _ -> "Not authorized")

  let authenticate_credentials request ~email ~password =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get Contract.repository
    in

    Repository.User.get_by_email ~email
    |> Sihl_core.Db.query_db request
    |> Lwt.map (fun user ->
           match user with
           | Ok user ->
               let _ =
                 Logs.info (fun m ->
                     m "got user with hash %s and password %s"
                       (Model.User.password user) password)
               in
               if Model.User.matches_password password user then Ok user
               else Error "Invalid password or email provided"
           | Error msg -> Error msg)

  (* Usually middleware gets its own module so the middleware constructor function
     is usually shortened to m. For example, [Auth.m] is obvious enough.
     The auth param (auth : username:string -> password:string -> user option)
     would represent our database model. E.g. it would do some lookup in the db
     and fetch the user. *)
  let middleware app =
    let filter handler req =
      let open Lwt.Infix in
      match req |> Request.headers |> Cohttp.Header.get_authorization with
      | None -> handler req
      | Some (`Other token) -> (
          (* TODO use more robust bearer token parsing *)
          let token = token |> String.split_on_char ' ' |> List.tl |> List.hd in
          authenticate_token req token >>= fun result ->
          match result with
          | Ok user ->
              let env = Opium.Hmap.add Env.key user (Request.env req) in
              let req = { req with Request.env } in
              handler req
          (* TODO error handling *)
          | Error msg ->
              Sihl_core.Fail.raise_not_authenticated
              @@ "wrong credentials provided msg=" ^ msg )
      | Some (`Basic (email, password)) -> (
          authenticate_credentials req ~email ~password >>= fun result ->
          match result with
          | Ok user ->
              let env = Opium.Hmap.add Env.key user (Request.env req) in
              let req = { req with Request.env } in
              handler req
          (* TODO error handling *)
          | Error msg ->
              Sihl_core.Fail.raise_not_authenticated
              @@ "wrong credentials provided msg=" ^ msg )
    in
    let m = Rock.Middleware.create ~name:"http auth" ~filter in
    Opium.Std.middleware m app

  let user req = Opium.Hmap.find Env.key (Request.env req)
end
