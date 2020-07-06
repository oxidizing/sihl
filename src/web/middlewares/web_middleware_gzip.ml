(* TODO
https://docs.djangoproject.com/en/3.0/ref/middleware/#module-django.middleware.gzip
 *)

let m =
  let filter handler req =
    Logs.warn (fun m -> m "gzip middleware is not implemented");
    handler req
  in
  Opium.Std.Rock.Middleware.create ~name:"gzip" ~filter
