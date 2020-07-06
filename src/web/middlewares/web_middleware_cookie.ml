let m () =
  let filter handler ctx =
    Logs.warn (fun m -> m "WEB: Cookie middleware is not implemented");
    handler ctx
  in
  (* TODO implement *)
  Web_middleware_core.create ~name:"cookie" filter
