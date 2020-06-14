open Base

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
      id = Sihl.Core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl.Core.Random.uuidv4 ();
      kind = "auth";
      user = Sihl.User.id user;
      status = "active";
    }

  let create_email_confirmation user =
    {
      id = Sihl.Core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl.Core.Random.uuidv4 ();
      kind = "email_confirmation";
      user = Sihl.User.id user;
      status = "active";
    }

  let create_password_reset user =
    {
      id = Sihl.Core.Random.uuidv4 ();
      (* TODO generate more compact random token *)
      value = Sihl.Core.Random.uuidv4 ();
      kind = "password_reset";
      user = Sihl.User.id user;
      status = "active";
    }
end

module Email = struct
  let sender () =
    Sihl.Core.Config.read_string ~default:"hello@oxidizing.io" "EMAIL_SENDER"

  let base_url () =
    Sihl.Core.Config.read_string ~default:"http://localhost:3000" "BASE_URL"

  let create_confirmation token user =
    let data =
      Sihl.Email.TemplateData.(
        empty
        |> add ~key:"base_url" ~value:(base_url ())
        |> add ~key:"token" ~value:(Token.value token))
    in
    Sihl.Email.make ~sender:(sender ()) ~recipient:(Sihl.User.email user)
      ~subject:"Email Address Confirmation" ~content:"" ~cc:[] ~bcc:[]
      ~html:false ~template_id:"fb7aec3f-2178-4166-beb4-79a3a663e093"
      ~template_data:data ()

  let create_password_reset token user =
    let data =
      Sihl.Email.TemplateData.(
        empty
        |> add ~key:"base_url" ~value:(base_url ())
        |> add ~key:"token" ~value:(Token.value token))
    in
    Sihl.Email.make ~sender:(sender ()) ~recipient:(Sihl.User.email user)
      ~subject:"Password Reset" ~content:"" ~cc:[] ~bcc:[] ~html:false
      ~template_id:"fb7aec3f-2178-4166-beb4-79a3a663e092" ~template_data:data ()
end
