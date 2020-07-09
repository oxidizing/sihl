open Base

module User = struct
  (* TODO add Status.Active and Status.Inactive *)
  (* TODO add roles ADT with user, staff and superuser *)
  (* TODO Ptime.t created_at *)

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

  let ctx_key : t Core.Ctx.key = Core.Ctx.create_key ()

  let confirm user = { user with confirmed = true }

  let set_user_password user new_password =
    let hash = new_password |> Utils.Hashing.hash |> Result.ok_or_failwith in
    { user with password = hash }

  let set_user_details user ~email ~username = { user with email; username }

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  let is_confirmed user = user.confirmed

  let matches_password password user =
    Utils.Hashing.matches ~hash:user.password ~plain:password

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

  let default_password_policy password =
    if String.length password > 8 then Ok ()
    else Error "Password has to contain at least 8 characters"

  let create ~email ~password ~username ~admin ~confirmed =
    let hash = password |> Utils.Hashing.hash |> Result.ok_or_failwith in
    {
      id = Data.Id.random () |> Data.Id.to_string;
      email;
      password = hash;
      username;
      admin;
      confirmed;
      status = "active";
    }

  let system =
    create ~email:"system" ~password:"" ~username:None ~admin:true
      ~confirmed:true

  let t =
    let encode m =
      Ok
        ( m.id,
          ( m.email,
            (m.username, (m.password, (m.status, (m.admin, m.confirmed)))) ) )
    in
    let decode
        (id, (email, (username, (password, (status, (admin, confirmed)))))) =
      Ok { id; email; username; password; status; admin; confirmed }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string
           (tup2 string
              (tup2 (option string)
                 (tup2 string (tup2 string (tup2 bool bool)))))))
end

(* module Email = struct
 *   let sender () =
 *     Sihl.Config.read_string ~default:"hello@oxidizing.io" "EMAIL_SENDER"
 *
 *   let base_url () =
 *     Sihl.Config.read_string ~default:"http://localhost:3000" "BASE_URL"
 *
 *   let create_confirmation token user =
 *     let data =
 *       Sihl.Email.TemplateData.(
 *         empty
 *         |> add ~key:"base_url" ~value:(base_url ())
 *         |> add ~key:"token" ~value:(Sihl.User.Token.value token))
 *     in
 *     Sihl.Email.make ~sender:(sender ()) ~recipient:(Sihl.User.email user)
 *       ~subject:"Email Address Confirmation" ~content:"" ~cc:[] ~bcc:[]
 *       ~html:false ~template_id:"fb7aec3f-2178-4166-beb4-79a3a663e093"
 *       ~template_data:data ()
 *
 *   let create_password_reset token user =
 *     let data =
 *       Sihl.Email.TemplateData.(
 *         empty
 *         |> add ~key:"base_url" ~value:(base_url ())
 *         |> add ~key:"token" ~value:(Sihl.User.Token.value token))
 *     in
 *     Sihl.Email.make ~sender:(sender ()) ~recipient:(Sihl.User.email user)
 *       ~subject:"Password Reset" ~content:"" ~cc:[] ~bcc:[] ~html:false
 *       ~template_id:"fb7aec3f-2178-4166-beb4-79a3a663e092" ~template_data:data ()
 * end *)
