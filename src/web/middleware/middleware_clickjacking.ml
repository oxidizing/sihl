(* TODO
    Set the X-Frame-Options HTTP header in HTTP responses.
    Do not set the header if it's already set or if the response contains
    a xframe_options_exempt value set to True.
    By default, set the X-Frame-Options header to 'SAMEORIGIN', meaning the
    response can only be loaded on a frame within the same site. To prevent the
    response from being loaded in a frame in any site, set X_FRAME_OPTIONS in
    your project's Django settings to 'DENY'.
 *)

module Make (Log : Log.Service.Sig.SERVICE) = struct
  let m () =
    let filter handler req =
      Logs.warn (fun m -> m "clickjacking middleware is not implemented");
      handler req
    in
    Opium.Std.Rock.Middleware.create ~name:"clickjacking" ~filter
end
