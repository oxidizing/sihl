let m () =
  let static_files_path =
    Config.read_string ~default:"./static" "STATIC_FILES_DIR"
    |> Base.Result.ok_or_failwith
  in
  Opium.Std.Middleware.static ~local_path:static_files_path
    ~uri_prefix:"/assets" ()
