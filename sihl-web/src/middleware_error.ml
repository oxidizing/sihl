let m () =
  let filter handler req = handler req in
  Opium_kernel.Rock.Middleware.create ~name:"error handler" ~filter
;;
