module Make (UserService : Sig.SERVICE) = struct
  let admin ~email ~password = UserService.create_admin ~email ~password ~username:None

  let user ~email ~password ?username () =
    UserService.create_user ~email ~password ~username
  ;;
end
