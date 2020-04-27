open Base
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

  let t =
    let encode m =
      Ok
        ( m.id,
          ( m.email,
            ( m.username,
              ( m.password,
                (m.name, (m.phone, (m.status, (m.admin, m.confirmed)))) ) ) ) )
    in
    let decode
        ( id,
          ( email,
            (username, (password, (name, (phone, (status, (admin, confirmed))))))
          ) ) =
      let _ = Logs.info (fun m -> m "received user with id %s" id) in
      Ok
        { id; email; username; password; name; phone; status; admin; confirmed }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string
           (tup2 string
              (tup2 string
                 (tup2 string
                    (tup2 string
                       (tup2 (option string) (tup2 string (tup2 bool bool)))))))))

  let confirm user = { user with confirmed = true }

  let update_password user new_password =
    let hash = Sihl_core.Hashing.hash new_password in
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
    let hash = Sihl_core.Hashing.hash password in
    {
      id = Sihl_core.Random.uuidv4 ();
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

  let t =
    let encode m = Ok (m.id, (m.value, (m.kind, (m.user, m.status)))) in
    let decode (id, (value, (kind, (user, status)))) =
      Ok { id; value; kind; user; status }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string (tup2 string (tup2 string (tup2 string string)))))

  let to_tuple token =
    (token.id, token.value, token.kind, token.user, token.status)

  let of_tuple (id, value, kind, user, status) =
    { id; value; kind; user; status }

  let is_valid_email_configuration token =
    String.equal token.status "active"
    && String.equal token.kind "email_confirmation"

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
