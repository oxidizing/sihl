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

let is_valid_email_configuration token =
  String.equal token.status "active"
  && String.equal token.kind "email_confirmation"

let is_valid_auth token =
  String.equal token.status "active" && String.equal token.kind "auth"

let can_reset_password token =
  String.equal token.status "active" && String.equal token.kind "password_reset"

let inactivate token = { token with status = "inactive" }

let create user =
  {
    id = Data.Id.random () |> Data.Id.to_string;
    (* TODO generate more compact random token *)
    value = Data.Id.random () |> Data.Id.to_string;
    kind = "auth";
    user = User.id user;
    status = "active";
  }

let create_email_confirmation user =
  {
    id = Data.Id.random () |> Data.Id.to_string;
    (* TODO generate more compact random token *)
    value = Data.Id.random () |> Data.Id.to_string;
    kind = "email_confirmation";
    user = User.id user;
    status = "active";
  }

let create_password_reset user =
  {
    id = Data.Id.random () |> Data.Id.to_string;
    (* TODO generate more compact random token *)
    value = Data.Id.random () |> Data.Id.to_string;
    kind = "password_reset";
    user = User.id user;
    status = "active";
  }
