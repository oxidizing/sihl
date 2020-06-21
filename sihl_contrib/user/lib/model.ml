open Base

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
        |> add ~key:"token" ~value:(Sihl.User.Token.value token))
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
        |> add ~key:"token" ~value:(Sihl.User.Token.value token))
    in
    Sihl.Email.make ~sender:(sender ()) ~recipient:(Sihl.User.email user)
      ~subject:"Password Reset" ~content:"" ~cc:[] ~bcc:[] ~html:false
      ~template_id:"fb7aec3f-2178-4166-beb4-79a3a663e092" ~template_data:data ()
end
