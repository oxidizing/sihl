let middleware () =
  let local_path =
    Option.value
      (Sihl_core.Configuration.read_string "PUBLIC_DIR")
      ~default:"./public"
  in
  let internal_uri_prefix =
    Option.value
      (Sihl_core.Configuration.read_string "PUBLIC_URI_PREFIX")
      ~default:"/assets"
  in
  let uri_prefix = Http.externalize_path internal_uri_prefix in
  Opium.Middleware.static_unix ~local_path ~uri_prefix ()
;;
