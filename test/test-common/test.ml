open Alcotest_lwt

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (SessionService : Sihl.Session.Sig.SERVICE)
    (UserService : Sihl.User.Sig.SERVICE)
    (StorageService : Sihl.Storage.Sig.SERVICE) =
struct
  module TestSession =
    Test_session.Make (DbService) (RepoService) (SessionService)

  let session =
    ( "session",
      [
        test_case "test anonymous request return cookie" `Quick
          TestSession.test_anonymous_request_returns_cookie;
        test_case "test requests persist session variable" `Quick
          TestSession.test_requests_persist_session_variables;
      ] )

  module TestStorage = Test_storage.Make (DbService) (StorageService)

  let storage =
    ( "storage",
      [
        test_case "upload file" `Quick TestStorage.fetch_uploaded_file;
        test_case "update file" `Quick TestStorage.update_uploaded_file;
      ] )

  module TestUser =
    Test_user.Make ((
      DbService : Sihl.Data.Db.Sig.SERVICE ))
      ((
      RepoService : Sihl.Data.Repo.Sig.SERVICE ))
      ((
      UserService : Sihl.User.Sig.SERVICE ))

  let user =
    ( "user",
      [
        test_case "update details" `Quick TestUser.update_details;
        test_case "update password" `Quick TestUser.update_password;
        test_case "update password fails" `Quick TestUser.update_password_fails;
        test_case "filter users by email" `Quick TestUser.filter_users_by_email;
      ] )
end
