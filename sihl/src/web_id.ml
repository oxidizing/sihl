let key : string Opium.Context.key =
  Opium.Context.Key.create ("id", Sexplib.Std.sexp_of_string)
;;

let find req = Opium.Context.find key req.Opium.Request.env

let set id req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key id env in
  { req with env }
;;

let middleware ?(id = (fun () -> Core_random.base64 64)) () =
  let filter handler req =
    match Opium.Request.header "x-request-id" req with
    | Some request_id -> handler (set request_id req)
    | None ->
      let request_id = id () in
      handler (set request_id req)
  in
  Rock.Middleware.create ~name:"id" ~filter
;;
