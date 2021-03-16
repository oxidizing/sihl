let key : string Opium.Context.key =
  Opium.Context.Key.create ("id", Sexplib.Std.sexp_of_string)
;;

exception Id_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No id found");
    Logs.info (fun m -> m "Have you applied the ID middleware for this route?");
    raise @@ Id_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set id req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key id env in
  { req with env }
;;

let middleware =
  let filter handler req =
    match Opium.Request.header "x-request-id" req with
    | Some request_id -> handler (set request_id req)
    | None ->
      let request_id = Core_random.base64 64 in
      handler (set request_id req)
  in
  Rock.Middleware.create ~name:"id" ~filter
;;
