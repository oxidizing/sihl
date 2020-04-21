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

  let update_password user new_password = { user with password = new_password }

  let update_details user ~email ~username ~name ~phone =
    { user with email; username; name; phone }

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  (* TODO use password hashing *)
  let matches_password password user = String.equal user.password password

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
    {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      email;
      password;
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
Hi {givenName} {familyName},

Thanks for signing up.

Please go to this URL to confirm your email address: {baseUrl}/app/confirm-email?token={token}

Best,
Josef
                  |}

    let create token user =
      let text =
        Sihl_core.Email.render
          [
            ("base_url", "TODO");
            ("root", "users");
            ("name", User.name user);
            ("token", Token.value token);
          ]
          template
      in
      Sihl_core.Email.create ~sender:"josef@oxdizing.io" ~recipient:user.email
        ~subject:"Email Address Confirmation" ~text
  end
end
