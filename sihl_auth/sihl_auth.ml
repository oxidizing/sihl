let handlers _ =
  Handlers.login "/login"
  @ Handlers.logout "/logout"
  @ Handlers.verify "/verify"
;;
