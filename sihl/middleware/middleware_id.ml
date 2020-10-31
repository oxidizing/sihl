let set id req =
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add Http.Request.key id env in
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
