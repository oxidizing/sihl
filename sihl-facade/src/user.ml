open Sihl_contract.User

module Hashing = struct
  let hash ?count plain =
    match count, not (Sihl_core.Configuration.is_production ()) with
    | _, true -> Ok (Bcrypt.hash ~count:4 plain |> Bcrypt.string_of_hash)
    | Some count, false ->
      if count < 4 || count > 31
      then Error "Password hashing count has to be between 4 and 31"
      else Ok (Bcrypt.hash ~count plain |> Bcrypt.string_of_hash)
    | None, false -> Ok (Bcrypt.hash ~count:10 plain |> Bcrypt.string_of_hash)
  ;;

  let matches ~hash ~plain = Bcrypt.verify plain (Bcrypt.hash_of_string hash)
end

let to_sexp
    { id; email; username; status; admin; confirmed; created_at; updated_at; _ }
  =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "email"; sexp_of_string email ]
    ; List [ Atom "username"; sexp_of_option sexp_of_string username ]
    ; List [ Atom "password"; sexp_of_string "********" ]
    ; List [ Atom "status"; sexp_of_string status ]
    ; List [ Atom "admin"; sexp_of_bool admin ]
    ; List [ Atom "confirmed"; sexp_of_bool confirmed ]
    ; List [ Atom "created_at"; sexp_of_string (Ptime.to_rfc3339 created_at) ]
    ; List [ Atom "updated_at"; sexp_of_string (Ptime.to_rfc3339 updated_at) ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)

let of_yojson json =
  let open Yojson.Safe.Util in
  try
    let id = json |> member "id" |> to_string in
    let email = json |> member "email" |> to_string in
    let username = json |> member "username" |> to_string_option in
    let password = json |> member "password" |> to_string in
    let status = json |> member "status" |> to_string in
    let admin = json |> member "admin" |> to_bool in
    let confirmed = json |> member "confirmed" |> to_bool in
    let created_at = json |> member "created_at" |> to_string in
    let updated_at = json |> member "updated_at" |> to_string in
    match Ptime.of_rfc3339 created_at, Ptime.of_rfc3339 updated_at with
    | Ok (created_at, _, _), Ok (updated_at, _, _) ->
      Some
        { id
        ; email
        ; username
        ; password
        ; status
        ; admin
        ; confirmed
        ; created_at
        ; updated_at
        }
    | _ -> None
  with
  | _ -> None
;;

let to_yojson user =
  let created_at = Ptime.to_rfc3339 user.created_at in
  let updated_at = Ptime.to_rfc3339 user.updated_at in
  let list =
    [ "id", `String user.id
    ; "email", `String user.email
    ; "password", `String user.password
    ; "status", `String user.status
    ; "admin", `Bool user.admin
    ; "confirmed", `Bool user.confirmed
    ; "created_at", `String created_at
    ; "updated_at", `String updated_at
    ]
  in
  match user.username with
  | Some username -> `Assoc (List.cons ("username", `String username) list)
  | None -> `Assoc (List.cons ("username", `Null) list)
;;

let confirm user = { user with confirmed = true }

let set_user_password user new_password =
  let hash = new_password |> Hashing.hash in
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
  Hashing.matches ~hash:user.password ~plain:password
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
  let hash = password |> Hashing.hash in
  let now = Ptime_clock.now () in
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
      ; created_at = now
      ; updated_at = now
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
  Service.set_password
    ?password_policy
    ~user
    ~password
    ~password_confirmation
    ()
;;

let create_user ~email ~password ~username =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.create_user ~email ~password ~username
;;

let create_admin ~email ~password ~username =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.create_admin ~email ~password ~username
;;

let register_user
    ?password_policy
    ?username
    ~email
    ~password
    ~password_confirmation
    ()
  =
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
