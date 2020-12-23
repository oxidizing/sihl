let key : string Opium.Context.key =
  Opium.Context.Key.create ("token", Sexplib.Std.(sexp_of_string))
;;

let find req = Opium.Context.find_exn key req.Opium.Request.env
let find_opt req = Opium.Context.find key req.Opium.Request.env

let set token req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key token env in
  { req with env }
;;

let middleware =
  let filter handler req =
    match Opium.Request.header "authorization" req with
    | Some authorization ->
      (match String.split_on_char ' ' authorization with
      | [ "Bearer"; token ] ->
        let req = set token req in
        handler req
      | [ "bearer"; token ] ->
        let req = set token req in
        handler req
      | _ -> handler req)
    | None -> handler req
  in
  Rock.Middleware.create ~name:"bearer" ~filter
;;
