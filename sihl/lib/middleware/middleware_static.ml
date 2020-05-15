let m () =
  let static_files_path =
    Core_config.read_string ~default:"./static" "STATIC_FILES_DIR"
  in
  Opium.Std.middleware
  @@ Opium.Std.Middleware.static ~local_path:static_files_path
       ~uri_prefix:"/assets" ()
