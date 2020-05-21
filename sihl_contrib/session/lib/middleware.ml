(* TODO
https://docs.djangoproject.com/en/3.0/topics/http/sessions/
*)

let session () app =
  let filter handler req =
    Logs.warn (fun m -> m "session middleware is not implemented");
    handler req
  in
  let m = Opium.Std.Rock.Middleware.create ~name:"session" ~filter in
  Opium.Std.middleware m app
