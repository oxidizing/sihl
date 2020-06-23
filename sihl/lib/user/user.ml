include User_model.User
module Sig = User_sig
module Token = User_model.Token

let get req ~user_id =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.get req ~user_id

let get_by_email req ~email =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.get_by_email req ~email

let get_all req =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.get_all req

let update_password req ~email ~old_password ~new_password =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.update_password req ~email ~old_password ~new_password

let set_password req ~user_id ~password =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.set_password req ~user_id ~password

let update_details req ~email ~username =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.update_details req ~email ~username

let create_user req ~email ~password ~username =
  let (module UserService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  UserService.create_user req ~email ~password ~username
