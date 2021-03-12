(* TODO [jerben] implement session middleware tests *)

let find_user id =
  if String.equal id "1"
  then
    Lwt.return
    @@ Some
         Sihl.Contract.User.
           { id = "1"
           ; email = "foo@example.com"
           ; username = None
           ; password = "123123"
           ; status = "active"
           ; admin = false
           ; confirmed = false
           ; created_at = Ptime_clock.now ()
           ; updated_at = Ptime_clock.now ()
           }
  else failwith "Invalid user id provided"
;;

let suite = [ "user", [] ]

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "web user" suite)
;;
