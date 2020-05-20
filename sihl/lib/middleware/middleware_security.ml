(* TODO
Set a couple of headers:
https://github.com/django/django/blob/master/django/middleware/security.py
 *)

let m app =
  let filter handler req =
    Logs.warn (fun m -> m "security middleware is not implemented");
    handler req
  in
  let m = Opium.Std.Rock.Middleware.create ~name:"security" ~filter in
  Opium.Std.middleware m app
