open Sihl_contract.User

type t = Sihl_contract.User.t

(* TODO [jerben] improve *)
let sexp_of_t { id; email; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]; List [ Atom "email"; sexp_of_string email ] ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (sexp_of_t t)

let of_yojson json =
  let open Yojson.Safe.Util in
  let ( let* ) = Option.bind in
  let* id = json |> member "id" |> to_string_option in
  let* email = json |> member "email" |> to_string_option in
  let username = json |> member "username" |> to_string_option in
  let* password = json |> member "password" |> to_string_option in
  let* status = json |> member "status" |> to_string_option in
  let* admin = json |> member "admin" |> to_bool_option in
  let* confirmed = json |> member "confirmed" |> to_bool_option in
  let* created_at = json |> member "created_at" |> to_string_option in
  match Ptime.of_rfc3339 created_at with
  | Ok (created_at, _, _) ->
    Some { id; email; username; password; status; admin; confirmed; created_at }
  | _ -> None
;;

let to_yojson user =
  let created_at = Ptime.to_rfc3339 user.created_at in
  let list =
    [ "id", `String user.id
    ; "email", `String user.email
    ; "password", `String user.password
    ; "status", `String user.status
    ; "admin", `Bool user.admin
    ; "confirmed", `Bool user.confirmed
    ; "created_at", `String created_at
    ]
  in
  match user.username with
  | Some username -> `Assoc (List.cons ("username", `String username) list)
  | None -> `Assoc (List.cons ("username", `Null) list)
;;

let confirm user = { user with confirmed = true }

let set_user_password user new_password =
  let hash = new_password |> Sihl_core.Utils.Hashing.hash in
  Result.map (fun hash -> { user with password = hash }) hash
;;

let set_user_details user ~email ~username =
  (* TODO add support for lowercase UTF-8
   * String.lowercase only supports US-ASCII, but
   * email addresses can contain other letters
   * (https://tools.ietf.org/html/rfc6531) like umlauts.
   *)
  { user with email = String.lowercase_ascii email; username }
;;

let is_admin user = user.admin
let is_owner user id = String.equal user.id id
let is_confirmed user = user.confirmed

let matches_password password user =
  Sihl_core.Utils.Hashing.matches ~hash:user.password ~plain:password
;;

let default_password_policy password =
  if String.length password >= 8
  then Ok ()
  else Error "Password has to contain at least 8 characters"
;;

let validate_new_password ~password ~password_confirmation ~password_policy =
  let is_same =
    if String.equal password password_confirmation
    then Ok ()
    else Error "Password confirmation doesn't match provided password"
  in
  let complies_with_policy = password_policy password in
  match is_same, complies_with_policy with
  | Ok (), Ok () -> Ok ()
  | Error msg, _ -> Error msg
  | _, Error msg -> Error msg
;;

let validate_change_password
    user
    ~old_password
    ~new_password
    ~new_password_confirmation
    ~password_policy
  =
  let matches_old_password =
    match matches_password old_password user with
    | true -> Ok ()
    | false -> Error "Invalid current password provided"
  in
  let new_password_valid =
    validate_new_password
      ~password:new_password
      ~password_confirmation:new_password_confirmation
      ~password_policy
  in
  match matches_old_password, new_password_valid with
  | Ok (), Ok () -> Ok ()
  | Error msg, _ -> Error msg
  | _, Error msg -> Error msg
;;

let make ~email ~password ~username ~admin ~confirmed =
  let hash = password |> Sihl_core.Utils.Hashing.hash in
  Result.map
    (fun hash ->
      { id = Uuidm.v `V4 |> Uuidm.to_string
      ; (* TODO add support for lowercase UTF-8
         * String.lowercase only supports US-ASCII, but
         * email addresses can contain other letters
         * (https://tools.ietf.org/html/rfc6531) like umlauts.
         *)
        email = String.lowercase_ascii email
      ; password = hash
      ; username
      ; admin
      ; confirmed
      ; status = "active"
      ; created_at = Ptime_clock.now ()
      })
    hash
;;

let instance : (module Sig) option ref = ref None

let create ~email ~password ~username ~admin ~confirmed =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.create ~email ~password ~username ~admin ~confirmed
;;

let search ?sort ?filter limit =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.search ?sort ?filter limit
;;

let find_opt ~user_id =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.find_opt ~user_id
;;

let find ~user_id =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.find ~user_id
;;

let find_by_email ~email =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.find_by_email ~email
;;

let find_by_email_opt ~email =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
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
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.update_password
    ?password_policy
    ~user
    ~old_password
    ~new_password
    ~new_password_confirmation
    ()
;;

let update_details ~user ~email ~username =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.update_details ~user ~email ~username
;;

let set_password ?password_policy ~user ~password ~password_confirmation () =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.set_password ?password_policy ~user ~password ~password_confirmation ()
;;

let create_user ~email ~password ~username =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.create_user ~email ~password ~username
;;

let create_admin ~email ~password ~username =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.create_admin ~email ~password ~username
;;

let register_user ?password_policy ?username ~email ~password ~password_confirmation () =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.register_user
    ?password_policy
    ?username
    ~email
    ~password
    ~password_confirmation
    ()
;;

let login ~email ~password =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.login ~email ~password
;;

let lifecycle () =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
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
