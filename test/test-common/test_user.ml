open Lwt.Syntax
open Base
open Alcotest_lwt

module Make
    (DbService : Sihl.Data.Db.Service.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Service.Sig.SERVICE)
    (UserService : Sihl.User.Service.Sig.SERVICE) =
struct
  module Seed = Sihl.User.Seed.Make (UserService)

  let update_details _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let* user =
      Seed.user ctx ~email:"foobar@example.com" ~password:"123123123"
    in
    let* updated_user =
      UserService.update_details ctx ~user ~email:"new@example.com"
        ~username:(Some "foo")
    in
    let actual_email = Sihl.User.email updated_user in
    let actual_username = Sihl.User.username updated_user in
    Alcotest.(check string "Has updated email" "new@example.com" actual_email);
    Alcotest.(
      check (option string) "Has updated username" (Some "foo") actual_username);
    Lwt.return ()

  let update_password _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let* user =
      Seed.user ctx ~email:"foobar@example.com" ~password:"123123123"
    in
    let* _ =
      UserService.update_password ctx ~user ~old_password:"123123123"
        ~new_password:"12345678" ~new_password_confirmation:"12345678" ()
      |> Lwt.map Result.ok_or_failwith
    in
    let* user =
      UserService.login ctx ~email:"foobar@example.com" ~password:"12345678"
      |> Lwt.map Result.ok_or_failwith
    in
    let actual_email = Sihl.User.email user in
    Alcotest.(
      check string "Can login with updated password" "foobar@example.com"
        actual_email);
    Lwt.return ()

  let update_password_fails _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let* user =
      Seed.user ctx ~email:"foobar@example.com" ~password:"123123123"
    in
    let* change_result =
      UserService.update_password ctx ~user ~old_password:"wrong_old_password"
        ~new_password:"12345678" ~new_password_confirmation:"12345678" ()
    in
    Alcotest.(
      check
        (result Sihl.User.alcotest string)
        "Can login with updated password"
        (Error "Invalid current password provided") change_result);
    Lwt.return ()

  let filter_users_by_email _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let* user1 =
      Seed.user ctx ~email:"user1@example.com" ~password:"123123123"
    in
    let* _ = Seed.user ctx ~email:"user2@example.com" ~password:"123123123" in
    let* _ = Seed.user ctx ~email:"user3@example.com" ~password:"123123123" in
    let filter =
      Sihl.Data.Ql.Filter.(C { key = "email"; value = "%user1%"; op = Like })
    in
    let query = Sihl.Data.Ql.(empty |> set_limit 10 |> set_filter filter) in
    let* actual_users, meta = UserService.find_all ctx ~query in
    Alcotest.(check int "has correct meta" 1 (Sihl.Data.Repo.Meta.total meta));
    Alcotest.(
      check (list Sihl.User.alcotest) "has one user" actual_users [ user1 ]);
    Lwt.return ()

  let test_suite =
    ( "user",
      [
        test_case "update details" `Quick update_details;
        test_case "update password" `Quick update_password;
        test_case "update password fails" `Quick update_password_fails;
        test_case "filter users by email" `Quick filter_users_by_email;
      ] )
end
