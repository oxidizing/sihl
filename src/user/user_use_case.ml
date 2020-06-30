(* open Base
 *
 * let ( let* ) = Lwt_result.bind *)

(* TODO this should use services only, no repos *)
(* let is_valid_auth_token ctx token =
 *   let* token = UserRepo.Token.get ~value:token |> Sihl.Db.query ctx in
 *   token
 *   |> Option.value_map ~default:false ~f:Sihl.User.Token.is_valid_auth
 *   |> Result.return |> Lwt.return
 *
 * let get_by_token ctx token =
 *   let* token =
 *     UserRepo.Token.get ~value:token
 *     |> Sihl.Db.query ctx
 *     |> Lwt.map Result.ok_or_failwith
 *     |> Lwt.map (Result.of_option ~error:"User not found")
 *   in
 *   let token_user = token |> Sihl.User.Token.user in
 *   get ctx ~user_id:token_user
 *
 * let send_registration_email ctx user =
 *   let token = Sihl.User.Token.create_email_confirmation user in
 *   let* () = UserRepo.Token.insert token |> Sihl.Db.query ctx in
 *   let email = Model.Email.create_confirmation token user in
 *   Sihl.Email.send ctx email
 *
 * let register ?(suppress_email = false) ctx ~email ~password ~username =
 *   let* user = get_by_email ctx ~email in
 *   let* () =
 *     match user with
 *     | Some _ -> Lwt.return @@ Error "Email already taken"
 *     | None -> Lwt.return @@ Ok ()
 *   in
 *   let user =
 *     Sihl.User.create ~email ~password ~username ~admin:false ~confirmed:false
 *   in
 *   let* () = UserRepo.User.insert user |> Sihl.Db.query ctx in
 *   let* () =
 *     if suppress_email then Lwt.return @@ Ok ()
 *     else send_registration_email ctx user
 *   in
 *   Lwt.return @@ Ok user
 *
 * let create_admin ctx ~email ~password ~username =
 *   let* user = UserRepo.User.get_by_email ~email |> Sihl.Db.query ctx in
 *   let* () =
 *     match user with
 *     | Some _ -> Lwt.return @@ Error "Email already taken"
 *     | None -> Lwt.return @@ Ok ()
 *   in
 *   let user =
 *     Sihl.User.create ~email ~password ~username ~admin:true ~confirmed:true
 *   in
 *   let* () = UserRepo.User.insert user |> Sihl.Db.query ctx in
 *   Lwt.return @@ Ok user
 *
 * let create_user ctx ~email ~password ~username =
 *   let user =
 *     Sihl.User.create ~email ~password ~username ~admin:false ~confirmed:false
 *   in
 *   let* () = UserRepo.User.insert user |> Sihl.Db.query ctx in
 *   Lwt.return @@ Ok user
 *
 * let logout ctx user =
 *   let* () = Sihl.Session.remove_value ~key:"users.id" ctx in
 *   let id = Sihl.User.id user in
 *   UserRepo.Token.delete_by_user ~id |> Sihl.Db.query ctx
 *
 * let login ctx ~email ~password =
 *   let* user =
 *     get_by_email ctx ~email
 *     |> Lwt.map Result.ok_or_failwith
 *     |> Lwt.map (Result.of_option ~error:"Invalid user provided")
 *   in
 *   if Sihl.User.matches_password password user then
 *     let token = Sihl.User.Token.create user in
 *     let* () = UserRepo.Token.insert token |> Sihl.Db.query ctx in
 *     Lwt.return @@ Ok token
 *   else Lwt.return @@ Error "Wrong credentials provided"
 *
 * let authenticate_credentials ctx ~email ~password =
 *   let* user =
 *     get_by_email ctx ~email
 *     |> Lwt.map Result.ok_or_failwith
 *     |> Lwt.map (Result.of_option ~error:"Invalid user provided")
 *   in
 *   if Sihl.User.matches_password password user then Lwt.return @@ Ok user
 *   else Lwt.return @@ Error "Wrong credentials provided"
 *
 * let token ctx user =
 *   let token = Sihl.User.Token.create user in
 *   let* () = UserRepo.Token.insert token |> Sihl.Db.query ctx in
 *   Lwt.return @@ Ok token *)

(* let confirm_email ctx token =
 *   let* token =
 *     UserRepo.Token.get ~value:token |> Sihl.Db.query ctx
 *   in
 *   let token =
 *     token |> Sihl.Core.Err.with_bad_ctx "invalid token provided"
 *   in
 *   if not @@ Sihl.User.Token.is_valid_email_configuration token then
 *     Sihl.Core.Err.raise_bad_ctx "invalid confirmation token provided"
 *   else
 *     Sihl.Db.query_with_trx_exn ctx (fun connection ->
 *         let* () =
 *           UserRepo.Token.update (Sihl.User.Token.inactivate token) connection
 *           |> Sihl.Core.Err.database
 *         in
 *         let* user =
 *           UserRepo.User.get ~id:token.user connection
 *           |> Sihl.Core.Err.database
 *         in
 *         UserRepo.User.update (Sihl.User.confirm user) connection)
 *
 * let ctx_password_reset ctx ~email =
 *   let* user = get_by_email ctx ~email in
 *   let token = Sihl.User.Token.create_password_reset user in
 *   let* () =
 *     UserRepo.Token.insert token |> Sihl.Db.query_exn ctx
 *   in
 *   let email = Model.Email.create_password_reset token user in
 *   let* result = Sihl.Email.send ctx email in
 *   result |> Sihl.Core.Err.with_email |> Lwt.return
 *
 * let reset_password ctx ~token ~new_password =
 *   let* token =
 *     UserRepo.Token.get ~value:token |> Sihl.Db.query ctx
 *   in
 *   let token =
 *     token |> Sihl.Core.Err.with_bad_ctx "invalid token provided"
 *   in
 *   if not @@ Sihl.User.Token.can_reset_password token then
 *     Sihl.Core.Err.raise_bad_ctx "invalid or inactive token provided"
 *   else
 *     let* user =
 *       UserRepo.User.get ~id:token.user |> Sihl.Db.query ctx
 *     in
 *     let user =
 *       user |> Sihl.Core.Err.with_bad_ctx "invalid user for token found"
 *     in
 *     (\* TODO use transaction here *\)
 *     let updated_user = Sihl.User.update_password user new_password in
 *     let* () =
 *       UserRepo.User.update updated_user |> Sihl.Db.query_exn ctx
 *     in
 *     let token = Sihl.User.Token.inactivate token in
 *     UserRepo.Token.update token |> Sihl.Db.query_exn ctx *)
