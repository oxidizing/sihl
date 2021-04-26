let ptime_to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

let ptime_of_yojson json =
  let open Yojson.Safe.Util in
  try
    match json |> to_string |> Ptime.of_rfc3339 with
    | Ok (ptime, _, _) -> Ok ptime
    | Error _ ->
      Error
        (Format.sprintf "Failed to parse date %s" (Yojson.Safe.to_string json))
  with
  | _ ->
    Error
      (Format.sprintf "Failed to parse date %s" (Yojson.Safe.to_string json))
;;

type status =
  | Active
  | Inactive
[@@deriving yojson, show]

let status_of_string = function
  | "active" -> Ok Active
  | "inactive" -> Ok Inactive
  | other -> Error (Format.sprintf "Invalid user status '%s'" other)
;;

let status_to_string = function
  | Active -> "active"
  | Inactive -> "inactive"
;;

type t =
  { id : string
  ; email : string
  ; username : string option
  ; name : string option
  ; given_name : string option
  ; password : string
  ; status : status
  ; admin : bool
  ; confirmed : bool
  ; created_at : Ptime.t
        [@to_yojson ptime_to_yojson] [@of_yojson ptime_of_yojson]
  ; updated_at : Ptime.t
        [@to_yojson ptime_to_yojson] [@of_yojson ptime_of_yojson]
  }
[@@deriving yojson, show]

let show_name user =
  match user.given_name, user.name with
  | None, None -> None
  | Some name, None -> Some name
  | None, Some name -> Some name
  | Some given_name, Some family_name ->
    Some (Format.sprintf "%s %s" given_name family_name)
;;

exception Exception of string

let name = "user"

module type Sig = sig
  module Web : sig
    (** [user_from_token ?key read_token request] returns the user that is
        associated to the user id in the [Bearer] token of the [request].

        [key] is the key in the token associated with the user id. By default,
        the value is [user_id].

        [read_token] is a function that returns the associated value of [key] in
        a given token. *)
    val user_from_token
      :  ?key:string
      -> (string -> k:string -> string option Lwt.t)
      -> Rock.Request.t
      -> t option Lwt.t

    (** [user_from_session ?cookie_key ?secret ?key ?secret request] returns the
        user that is associated to the user id in the session of the [request].

        [cookie_key] is the name/key of the session cookie. By default, the
        value is [_session].

        [secret] is used to verify the signature of the session cookie. By
        default, [SIHL_SECRET] is used.

        [key] is the key in the session associated with the user id. By default,
        the value is [user_id]. *)
    val user_from_session
      :  ?cookie_key:string
      -> ?secret:string
      -> ?key:string
      -> Rock.Request.t
      -> t option Lwt.t
  end

  (** [search ?sort ?filter ?limit ?offset ()] returns a list of users that is a
      partial view on all stored users.

      [sort] is the default sorting order of the created date. By default, this
      value is [`Desc].

      [filter] is a search keyword that is applied in a best-effort way on user
      details. The keyword has to occur in only one field (such as email).

      [limit] is the length of the returned list.

      [offset] is the pagination offset of the partial view. *)
  val search
    :  ?sort:[ `Desc | `Asc ]
    -> ?filter:string
    -> ?limit:int
    -> ?offset:int
    -> unit
    -> (t list * int) Lwt.t

  (** [find_opt id] returns a user with [id]. *)
  val find_opt : string -> t option Lwt.t

  (** [find id] returns a user with [id], [None] otherwise. *)
  val find : string -> t Lwt.t

  (** [find_by_email email] returns a [User.t] if there is a user with email
      address [email]. The lookup is case-insensitive. Raises an [{!Exception}]
      otherwise. *)
  val find_by_email : string -> t Lwt.t

  (** [find_by_email_opt email] returns a [User.t] if there is a user with email
      address [email]. *)
  val find_by_email_opt : string -> t option Lwt.t

  (** [update_password ?password_policy user ~old_password ~new_password
      ~new_password_confirmation]
      updates the password of a [user] to [new_password] and returns the user.
      The [old_password] is the current password that the user has to enter.
      [new_password] has to equal [new_password_confirmation].

      [password_policy] is a function that validates the [new_password] based on
      some password policy. By default, the policy is that a password has to be
      at least 8 characters long. *)
  val update_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> t
    -> old_password:string
    -> new_password:string
    -> new_password_confirmation:string
    -> (t, string) Result.t Lwt.t

  (** [update ?email ?username ?name ?given_name ?status user] stores the
      updated [user] and returns it. *)
  val update
    :  ?email:string
    -> ?username:string
    -> ?name:string
    -> ?given_name:string
    -> ?status:status
    -> t
    -> t Lwt.t

  val update_details
    :  user:t
    -> email:string
    -> username:string option
    -> t Lwt.t
    [@@deprecated "Use update() instead"]

  (** [set_password ?policy user ~password ~password_confirmation] overrides the
      current password of a [user] and returns that user. [password] has to
      equal [password_confirmation].

      [password_policy] is a function that validates the [new_password] based on
      some password policy. By default, the policy is that a password has to be
      at least 8 characters long.

      The current password doesn't have to be provided, therefore you should not
      expose this function to users but only admins. If you want the user to
      update their own password use {!update_password} instead. *)
  val set_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> t
    -> password:string
    -> password_confirmation:string
    -> (t, string) Result.t Lwt.t

  (** [create_user ?username ?name ?given_name email password] returns a
      non-admin user. Note that using [create_user] skips the registration
      workflow and should only be used with care.*)
  val create_user
    :  ?username:string
    -> ?name:string
    -> ?given_name:string
    -> password:string
    -> string
    -> t Lwt.t

  (** [create_admin ?username ?name ?given_name email password] returns an admin
      user. *)
  val create_admin
    :  ?username:string
    -> ?name:string
    -> ?given_name:string
    -> password:string
    -> string
    -> t Lwt.t

  (** [register_user ?password_policy ?username ?name ?given_name email password
      password_confirmation]
      creates a new user if the password is valid and if the email address was
      not already registered.

      Provide [password_policy] to check whether the password fulfills certain
      criteria. *)
  val register_user
    :  ?password_policy:(string -> (unit, string) result)
    -> ?username:string
    -> ?name:string
    -> ?given_name:string
    -> string
    -> password:string
    -> password_confirmation:string
    -> ( t
       , [ `Already_registered | `Invalid_password_provided of string ] )
       Result.t
       Lwt.t

  (** [login email ~password] returns the user associated with [email] if
      [password] matches the current password. *)
  val login
    :  string
    -> password:string
    -> (t, [ `Does_not_exist | `Incorrect_password ]) Result.t Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

let to_sexp
    { id
    ; email
    ; username
    ; name
    ; given_name
    ; status
    ; admin
    ; confirmed
    ; created_at
    ; updated_at
    ; _
    }
  =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "email"; sexp_of_string email ]
    ; List [ Atom "username"; sexp_of_option sexp_of_string username ]
    ; List [ Atom "name"; sexp_of_option sexp_of_string name ]
    ; List [ Atom "given_name"; sexp_of_option sexp_of_string given_name ]
    ; List [ Atom "password"; sexp_of_string "********" ]
    ; List [ Atom "status"; sexp_of_string (status_to_string status) ]
    ; List [ Atom "admin"; sexp_of_bool admin ]
    ; List [ Atom "confirmed"; sexp_of_bool confirmed ]
    ; List [ Atom "created_at"; sexp_of_string (Ptime.to_rfc3339 created_at) ]
    ; List [ Atom "updated_at"; sexp_of_string (Ptime.to_rfc3339 updated_at) ]
    ]
;;

(* Common *)
module Hashing = struct
  let hash ?count plain =
    match count, not (Core_configuration.is_production ()) with
    | _, true -> Ok (Bcrypt.hash ~count:4 plain |> Bcrypt.string_of_hash)
    | Some count, false ->
      if count < 4 || count > 31
      then Error "Password hashing count has to be between 4 and 31"
      else Ok (Bcrypt.hash ~count plain |> Bcrypt.string_of_hash)
    | None, false -> Ok (Bcrypt.hash ~count:10 plain |> Bcrypt.string_of_hash)
  ;;

  let matches ~hash ~plain = Bcrypt.verify plain (Bcrypt.hash_of_string hash)
end

let confirm user = { user with confirmed = true }

let set_user_password user new_password =
  let hash = new_password |> Hashing.hash in
  Result.map (fun hash -> { user with password = hash }) hash
;;

let set_user_details user ~email ~username = { user with email; username }
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

let make ~email ~password ~name ~given_name ~username ~admin ~confirmed =
  let hash = password |> Hashing.hash in
  let now = Ptime_clock.now () in
  Result.map
    (fun hash ->
      { id = Uuidm.v `V4 |> Uuidm.to_string
      ; email
      ; password = hash
      ; username
      ; name
      ; given_name
      ; admin
      ; confirmed
      ; status = Active
      ; created_at = now
      ; updated_at = now
      })
    hash
;;
