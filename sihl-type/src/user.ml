(* TODO [jerben] add Status.Active and Status.Inactive *)

module Error = struct
  type t =
    | AlreadyRegistered
    | IncorrectPassword
    | InvalidPasswordProvided of string
    | DoesNotExist
end

type t =
  { id : string
  ; email : string
  ; username : string option
  ; password : string
  ; status : string
  ; admin : bool
  ; confirmed : bool
  ; created_at : Ptime.t
        [@to_yojson Sihl_core.Time.ptime_to_yojson]
        [@of_yojson Sihl_core.Time.ptime_of_yojson]
  }
[@@deriving fields, yojson, show, make]

let equal u1 u2 = String.equal u1.id u2.id
let confirm user = { user with confirmed = true }

let sexp_of_t { id; email; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]; List [ Atom "email"; sexp_of_string email ] ]
;;

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

let create ~email ~password ~username ~admin ~confirmed =
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
