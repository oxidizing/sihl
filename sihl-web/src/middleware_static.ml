let m ~local_path_f ~uri_prefix_f =
  Opium.Middleware.static_unix ~local_path:(local_path_f ()) ~uri_prefix:(uri_prefix_f ())
;;
