module Make (UserService : User_sig.SERVICE) = struct
  let admin ~email ~password request =
    UserService.create_admin request ~email ~password ~username:None

  let user ~email ~password ?username request =
    UserService.create_user request ~email ~password ~username
end
