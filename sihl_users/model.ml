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
  [@@deriving sexp, fields, to_yojson]

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  (* TODO use password hashing *)
  let matches_password user password = String.equal user.password password

  let create ~email ~password ~username ~name =
    {
      id = "123";
      email;
      password;
      username;
      name;
      phone = None;
      status = "active";
      admin = false;
      confirmed = false;
    }
end

module Token = struct
  type t = {
    id : string;
    value : string;
    kind : string;
    token_user : string;
    status : string;
  }
  [@@deriving fields]

  let create user =
    {
      id = "123";
      value = "abc123";
      kind = "auth";
      token_user = User.id user;
      status = "active";
    }
end
