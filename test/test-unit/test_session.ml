(* TODO reenable once we have a in-memory implementation of the
   session repo *)

(* open Base
 *
 * let session_not_expired _ () =
 *   let expire_date =
 *     Option.value_exn
 *       ( 60 * 60 * 24
 *       |> Ptime.Span.of_int_s
 *       |> Ptime.add_span (Ptime_clock.now ()) )
 *   in
 *   let session =
 *     Option.value_exn (Sihl.Session.make ~expire_date (Ptime_clock.now ()))
 *   in
 *   Lwt.return
 *   @@ Alcotest.(
 *        check bool "is not expired" false
 *          (Sihl.Session.is_expired (Ptime_clock.now ()) session))
 *
 * let test_set_session_variable _ () =
 *   let open Sihl.Session in
 *   let session = Option.value_exn (make (Ptime_clock.now ())) in
 *   Alcotest.(check (option string))
 *     "Has no session variable" None (get "foo" session);
 *   let session = set ~key:"foo" ~value:"bar" session in
 *   Logs.debug (fun m -> m "got new session");
 *   Alcotest.(check (option string))
 *     "Has a session variable" (Some "bar") (get "foo" session);
 *   let session = set ~key:"foo" ~value:"baz" session in
 *   Alcotest.(check (option string))
 *     "Has overridden session variable" (Some "baz") (get "foo" session);
 *   Alcotest.(check (option string))
 *     "Has no other session variable" None (get "other" session);
 *   Lwt.return () *)
