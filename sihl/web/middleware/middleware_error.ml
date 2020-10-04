let m () =
  let filter handler req = handler req in
  Middleware_core.create ~name:"error handler" filter
;;
