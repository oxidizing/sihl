val user : login_path_f:(unit -> string) -> Rock.Middleware.t

val admin
  :  login_path_f:(unit -> string)
  -> (Sihl_contract.User.t -> bool)
  -> Rock.Middleware.t
