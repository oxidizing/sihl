let key : string Opium.Context.key =
  Opium.Context.Key.create ("token", Sexplib.Std.(sexp_of_string))
;;

exception Token_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No bearer token found");
    Logs.info (fun m ->
        m "Have you applied the bearer token middleware for this route?");
    raise @@ Token_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set token req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key token env in
  { req with env }
;;

let default_handler _ =
  Opium.Response.of_plain_text "Unauthorized 401"
  |> Opium.Response.set_status `Unauthorized
  |> Lwt.return
;;

let middleware ?(unauthenticated_handler = default_handler) () =
  let filter handler req =
    match Opium.Request.header "authorization" req with
    | Some authorization ->
      let bearer_token =
        try Some (Scanf.sscanf authorization "Bearer %s" (fun b -> b)) with
        | _ -> None
      in
      (match bearer_token with
      | None -> unauthenticated_handler req
      | Some bearer_token ->
        let req = set bearer_token req in
        handler req)
    | None -> unauthenticated_handler req
  in
  Rock.Middleware.create ~name:"token.bearer" ~filter
;;
