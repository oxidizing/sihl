let middleware () =
  let filter handler req =
    let uri = req.Opium.Request.target |> Uri.of_string in
    let uri =
      uri
      |> Uri.path
      |> CCString.rdrop_while (Char.equal '/')
      |> Uri.with_path uri
    in
    let req = Opium.Request.{ req with target = Uri.to_string uri } in
    handler req
  in
  Rock.Middleware.create ~name:"trailing_slash" ~filter
;;
