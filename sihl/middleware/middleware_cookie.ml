let m () =
  let filter handler ctx =
    Logs.warn (fun m -> m "WEB: Cookie middleware is not implemented");
    handler ctx
  in
  (* TODO [jerben] implement *)
  Opium_kernel.Rock.Middleware.create ~name:"cookie" ~filter
;;
