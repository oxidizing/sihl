(* TODO
https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works *)

let m () =
  let filter handler ctx =
    Logs.warn (fun m -> m "WEB: CSRF middleware is not implemented");
    handler ctx
  in
  Web_middleware_core.create ~name:"csrf" filter
