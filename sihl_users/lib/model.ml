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

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  (* TODO use password hashing *)
  let matches_password password user = String.equal user.password password

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
end
