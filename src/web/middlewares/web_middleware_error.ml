let m () =
  let filter handler req = handler req in
  Web_middleware_core.create ~name:"error handler" filter
