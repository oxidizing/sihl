(* TODO
https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works *)

let m =
  let filter handler req =
    Logs.warn (fun m -> m "csrf middleware is not implemented");
    handler req
  in
  Opium.Std.Rock.Middleware.create ~name:"csrf" ~filter
