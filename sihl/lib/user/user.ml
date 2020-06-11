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
  let hash = new_password |> Core.Hashing.hash |> Result.ok_or_failwith in
  { user with password = hash }

let update_details user ~email ~username = { user with email; username }

let is_admin user = user.admin

let is_owner user id = String.equal user.id id

let is_confirmed user = user.confirmed

let matches_password password user =
  Core.Hashing.does_match ~hash:user.password ~plain:password

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
  let hash = password |> Core.Hashing.hash |> Result.ok_or_failwith in
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

let t =
  let encode m =
    Ok
      ( m.id,
        (m.email, (m.username, (m.password, (m.status, (m.admin, m.confirmed)))))
      )
  in
  let decode (id, (email, (username, (password, (status, (admin, confirmed))))))
      =
    Ok { id; email; username; password; status; admin; confirmed }
  in
  Caqti_type.(
    custom ~encode ~decode
      (tup2 string
         (tup2 string
            (tup2 (option string) (tup2 string (tup2 string (tup2 bool bool)))))))
