open Base

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/sessions" ^ path

let test_fetch_any_endpoint_creates_anonymous_session _ () =
  let* () = Sihl.Run.Manage.clean () in
  let* _, _ = Cohttp_lwt_unix.Client.get (Uri.of_string @@ url "/foobar/") in
  let* request = Sihl.Run.Test.request_with_connection () in
  let (module Repository : Sihl_session.Repo_sig.REPOSITORY) =
    Sihl.Core.Registry.get Sihl_session.Bind.Repository.key
  in
  Logs.debug (fun m -> m "fetching all sessions");
  let* sessions = Repository.get_all |> Sihl.Core.Db.query_db request in
  let sessions = sessions |> Result.ok_or_failwith in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return @@ ()
