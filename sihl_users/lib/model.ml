open Core
open Sexplib.Std

module User = struct
  type t = {
    id : string;
    email : string;
    username : string;
    password : string;
    name : string;
    phone : string option;
    status : string;
    admin : bool;
    confirmed : bool;
  }
  [@@deriving sexp, fields, yojson]

  let confirm user = { user with confirmed = true }

  let update_password user new_password =
    (* TODO use a lower count when testing *)
    let hash = Bcrypt.hash ~count:5 new_password |> Bcrypt.string_of_hash in
    { user with password = hash }

  let update_details user ~email ~username ~name ~phone =
    { user with email; username; name; phone }

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  let matches_password password user =
    Bcrypt.verify password (Bcrypt.hash_of_string user.password)

  let validate_password password =
    (* TODO use more sophisticated policy *)
    if String.length password > 8 then Ok ()
    else Error "new password has to be longer than 8"

  let is_valid user ~old_password ~new_password =
    let matches_password =
      match matches_password old_password user with
      | true -> Ok ()
      | false -> Error "wrong current password provided"
    in
    let new_password_valid = validate_password new_password in
    Result.all_unit [ matches_password; new_password_valid ]

  let create ~email ~password ~username ~name ~phone ~admin ~confirmed =
    (* TODO use a lower count when testing *)
    let hash = Bcrypt.hash ~count:5 password |> Bcrypt.string_of_hash in
    {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      email;
      password = hash;
      username;
      name;
      phone;
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

  let can_reset_password token =
    String.equal token.status "active"
    && String.equal token.kind "password_reset"

  let inactivate token = { token with status = "inactive" }

  let create user =
    {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      (* TODO generate more compact random token *)
      value = Uuidm.v `V4 |> Uuidm.to_string;
      kind = "auth";
      user = User.id user;
      status = "active";
    }

  let create_email_confirmation user =
    {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      (* TODO generate more compact random token *)
      value = Uuidm.v `V4 |> Uuidm.to_string;
      kind = "email_confirmation";
      user = User.id user;
      status = "active";
    }

  let create_password_reset user =
    {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      (* TODO generate more compact random token *)
      value = Uuidm.v `V4 |> Uuidm.to_string;
      kind = "password_reset";
      user = User.id user;
      status = "active";
    }
end

module Email = struct
  module Confirmation = struct
    let template =
      {|
Hi {name},

Thanks for signing up.

Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token}

Best,
Josef
                  |}

    let create token user =
      let text =
        Sihl_core.Email.render
          [
            ("base_url", "http://localhost:3000");
            ("name", User.name user);
            ("token", Token.value token);
          ]
          template
      in
      Sihl_core.Email.create ~sender:"josef@oxdizing.io" ~recipient:user.email
        ~subject:"Email Address Confirmation" ~text
  end

  module PasswordReset = struct
    let template =
      {|
Hi {name},

You requested to reset your password.

Please go to this URL to reset your password: {base_url}/app/password-reset?token={token}

Best,
Josef
                  |}

    let create token user =
      let text =
        Sihl_core.Email.render
          [
            ("base_url", "http://localhost:3000");
            ("name", User.name user);
            ("token", Token.value token);
          ]
          template
      in
      Sihl_core.Email.create ~sender:"josef@oxdizing.io" ~recipient:user.email
        ~subject:"Password Reset" ~text
  end
end
