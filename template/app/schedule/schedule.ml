let hello =
  Sihl.Schedule.(
    create
      every_hour
      (fun () -> Lwt.return @@ print_endline "Hello! An hour has passed!")
      "hello")
;;
