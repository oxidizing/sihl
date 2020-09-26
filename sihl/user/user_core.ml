open Base

exception Exception of string

module User = struct
  (* TODO add Status.Active and Status.Inactive *)
  (* TODO roles that are managed by a role service *)

  type t = {
    id : string;
    email : string;
    username : string option;
    password : string;
    status : string;
    admin : bool;
    confirmed : bool;
    created_at : Ptime.t;
        [@to_yojson Utils.Time.ptime_to_yojson]
        [@of_yojson Utils.Time.ptime_of_yojson]
  }
  [@@deriving fields, yojson, show, make]

  let equal u1 u2 = String.equal u1.id u2.id

  let alcotest = Alcotest.testable pp equal

  let ctx_key : t Core.Ctx.key = Core.Ctx.create_key ()

  let confirm user = { user with confirmed = true }

  let set_user_password user new_password =
    let hash = new_password |> Utils.Hashing.hash in
    Result.map hash ~f:(fun hash -> { user with password = hash })

  let set_user_details user ~email ~username =
    (* TODO add support for lowercase UTF-8
     * String.lowercase only supports US-ASCII, but
     * email addresses can contain other letters
     * (https://tools.ietf.org/html/rfc6531) like umlauts.
     *)
    { user with email = String.lowercase email; username }

  let is_admin user = user.admin

  let is_owner user id = String.equal user.id id

  let is_confirmed user = user.confirmed

  let matches_password password user =
    Utils.Hashing.matches ~hash:user.password ~plain:password

  let default_password_policy password =
    if String.length password >= 8 then Ok ()
    else Error "Password has to contain at least 8 characters"

  let validate_new_password ~password ~password_confirmation ~password_policy =
    let is_same =
      if String.equal password password_confirmation then Ok ()
      else Error "Password confirmation doesn't match provided password"
    in
    let complies_with_policy = password_policy password in
    Result.all_unit [ is_same; complies_with_policy ]

  let validate_change_password user ~old_password ~new_password
      ~new_password_confirmation ~password_policy =
    let matches_old_password =
      match matches_password old_password user with
      | true -> Ok ()
      | false -> Error "Invalid current password provided"
    in
    let new_password_valid =
      validate_new_password ~password:new_password
        ~password_confirmation:new_password_confirmation ~password_policy
    in
    Result.all_unit [ matches_old_password; new_password_valid ]

  let create ~email ~password ~username ~admin ~confirmed =
    let hash = password |> Utils.Hashing.hash in
    Result.map hash ~f:(fun hash ->
        {
          id = Data.Id.random () |> Data.Id.to_string;
          (* TODO add support for lowercase UTF-8
           * String.lowercase only supports US-ASCII, but
           * email addresses can contain other letters
           * (https://tools.ietf.org/html/rfc6531) like umlauts.
           *)
          email = String.lowercase email;
          password = hash;
          username;
          admin;
          confirmed;
          status = "active";
          created_at = Ptime_clock.now ();
        })

  let t =
    let encode m =
      Ok
        ( m.id,
          ( m.email,
            ( m.username,
              (m.password, (m.status, (m.admin, (m.confirmed, m.created_at))))
            ) ) )
    in
    let decode
        ( id,
          ( email,
            (username, (password, (status, (admin, (confirmed, created_at)))))
          ) ) =
      Ok { id; email; username; password; status; admin; confirmed; created_at }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 string
           (tup2 string
              (tup2 (option string)
                 (tup2 string (tup2 string (tup2 bool (tup2 bool ptime))))))))
end
