open Base

type t = {
  id : string;
  email : string;
  username : string option;
  password : string;
  status : string;
  admin : bool;
  confirmed : bool;
}
[@@deriving sexp, fields, yojson, show, eq, make]

let confirm user = { user with confirmed = true }

let update_password user new_password =
  let hash = Core.Hashing.hash new_password in
  { user with password = hash }

let update_details user ~email ~username = { user with email; username }

let is_admin user = user.admin

let is_owner user id = String.equal user.id id

let is_confirmed user = user.confirmed

let matches_password password user =
  Bcrypt.verify password (Bcrypt.hash_of_string user.password)

let validate_password password =
  (* TODO use more sophisticated policy *)
  if String.length password > 8 then Ok ()
  else Error "new password has to be longer than 8"

let validate user ~old_password ~new_password =
  let matches_password =
    match matches_password old_password user with
    | true -> Ok ()
    | false -> Error "wrong current password provided"
  in
  let new_password_valid = validate_password new_password in
  Result.all_unit [ matches_password; new_password_valid ]

let create ~email ~password ~username ~admin ~confirmed =
  let hash = Core.Hashing.hash password in
  {
    id = Core.Random.uuidv4 ();
    email;
    password = hash;
    username;
    admin;
    confirmed;
    status = "active";
  }

let system =
  create ~email:"system" ~password:"" ~username:None ~admin:true ~confirmed:true
