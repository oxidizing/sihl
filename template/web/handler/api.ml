let hello _ =
  Lwt.return @@ Sihl.Web.Response.of_json (`Assoc [ "hello", `String "there" ])
;;
