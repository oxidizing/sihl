let middleware () =
  let local_path =
    Option.value
      (Core_configuration.read_string "PUBLIC_DIR")
      ~default:"./public"
  in
  let internal_uri_prefix =
    Option.value
      (Core_configuration.read_string "PUBLIC_URI_PREFIX")
      ~default:"/assets"
  in
  let uri_prefix = Web.externalize_path internal_uri_prefix in
  Opium.Middleware.static_unix ~local_path ~uri_prefix ()
;;
