open Base
open Sexplib.Std

module User = struct
  type t = {
    id : string;
    email : string;
    username : string option;
    password : string;
    status : string;
    admin : bool;
    confirmed : bool;
  }
  [@@deriving sexp, fields, yojson]

  let confirm user = { user with confirmed = true }

  let update_password user new_password =
    let hash = Sihl_core.Hashing.hash new_password in
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
    let hash = Sihl_core.Hashing.hash password in
    {
      id = Sihl_core.Random.uuidv4 ();
      email;
      password = hash;
      username;
      admin;
      confirmed;
      status = "active";
    }
end

module Token = struct
  type t = {
    id : string;
    value : string;
    kind : string;
    user : string;
    status : string;
  }
  [@@deriving fields]

  let is_valid_email_configuration token =
    String.equal token.status "active"
    && String.equal token.kind "email_confirmation"

  let is_valid_auth token =
    String.equal token.status "active" && String.equal token.kind "auth"

  let can_reset_password token =
    String.equal token.status "active"
    && String.equal token.kind "password_reset"

  let inactivate token = { token with status = "inactive" }

  let create user =
    {
      id = Sihl_core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl_core.Random.uuidv4 ();
      kind = "auth";
      user = User.id user;
      status = "active";
    }

  let create_email_confirmation user =
    {
      id = Sihl_core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl_core.Random.uuidv4 ();
      kind = "email_confirmation";
      user = User.id user;
      status = "active";
    }

  let create_password_reset user =
    {
      id = Sihl_core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl_core.Random.uuidv4 ();
      kind = "password_reset";
      user = User.id user;
      status = "active";
    }
end

module Email = struct
  let sender () =
    Sihl_core.Config.read_string ~default:"hello@oxidizing.io" "EMAIL_SENDER"

  let base_url () =
    Sihl_core.Config.read_string ~default:"http://localhost:3000" "BASE_URL"

  let create_confirmation token user =
    Sihl_email.Model.Email.create ~sender:(sender ())
      ~recipient:(User.email user) ~subject:"Email Address Confirmation"
      ~content:"" ~cc:[] ~bcc:[] ~html:false
      ~template_id:(Some "fb7aec3f-2178-4166-beb4-79a3a663e093")
      ~template_data:[ ("base_url", base_url ()); ("token", Token.value token) ]

  let create_password_reset token user =
    Sihl_email.Model.Email.create ~sender:(sender ())
      ~recipient:(User.email user) ~subject:"Password Reset" ~content:"" ~cc:[]
      ~bcc:[] ~html:false
      ~template_id:(Some "fb7aec3f-2178-4166-beb4-79a3a663e092")
      ~template_data:[ ("base_url", base_url ()); ("token", Token.value token) ]
end
