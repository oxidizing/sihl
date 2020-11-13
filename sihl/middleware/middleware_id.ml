module Core = Sihl_core
module Http = Sihl_http

let key : string Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("id", Sexplib.Std.sexp_of_string)
;;

let find req = Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set id req =
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add key id env in
  { req with env }
;;

let m () =
  let filter handler req =
    let id = Core.Random.bytes ~nr:32 |> List.to_seq |> String.of_seq in
    let req = set id req in
    handler req
  in
  Opium_kernel.Rock.Middleware.create ~name:"authn_session" ~filter
;;
