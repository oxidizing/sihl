open Sihl_contract.User
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let search ?sort ?filter limit =
  let module Service = (val unpack name instance : Sig) in
  Service.search ?sort ?filter limit
;;

let find_opt ~user_id =
  let module Service = (val unpack name instance : Sig) in
  Service.find_opt ~user_id
;;

let find ~user_id =
  let module Service = (val unpack name instance : Sig) in
  Service.find ~user_id
;;

let find_by_email ~email =
  let module Service = (val unpack name instance : Sig) in
  Service.find_by_email ~email
;;

let find_by_email_opt ~email =
  let module Service = (val unpack name instance : Sig) in
  Service.find_by_email_opt ~email
;;

let update_password
    ?password_policy
    ~user
    ~old_password
    ~new_password
    ~new_password_confirmation
    ()
  =
  let module Service = (val unpack name instance : Sig) in
  Service.update_password
    ?password_policy
    ~user
    ~old_password
    ~new_password
    ~new_password_confirmation
    ()
;;

let update_details ~user ~email ~username =
  let module Service = (val unpack name instance : Sig) in
  Service.update_details ~user ~email ~username
;;

let set_password ?password_policy ~user ~password ~password_confirmation () =
  let module Service = (val unpack name instance : Sig) in
  Service.set_password ?password_policy ~user ~password ~password_confirmation ()
;;

let create_user ~email ~password ~username =
  let module Service = (val unpack name instance : Sig) in
  Service.create_user ~email ~password ~username
;;

let create_admin ~email ~password ~username =
  let module Service = (val unpack name instance : Sig) in
  Service.create_admin ~email ~password ~username
;;

let register_user ?password_policy ?username ~email ~password ~password_confirmation () =
  let module Service = (val unpack name instance : Sig) in
  Service.register_user
    ?password_policy
    ?username
    ~email
    ~password
    ~password_confirmation
    ()
;;

let login ~email ~password =
  let module Service = (val unpack name instance : Sig) in
  Service.login ~email ~password
;;

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;

module Seed = struct
  let admin ~email ~password = create_admin ~email ~password ~username:None
  let user ~email ~password ?username () = create_user ~email ~password ~username
end
