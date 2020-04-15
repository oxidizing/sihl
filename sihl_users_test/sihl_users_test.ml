open Lwt.Infix

open Sihl_users.Service.User

(* The tests *)
let test_exn () =
  Alcotest.check_raises "custom exception" Library_exception exn

let lwt_check_raises f =
  Lwt.catch
    (fun () -> f () >|= fun () -> `Ok)
    (function e -> Lwt.return @@ `Error e)
  >|= function
  | `Ok -> Alcotest.fail "No exception was thrown"
  | `Error Library_exception -> Alcotest.(check pass) "Correct exception" () ()
  | `Error _ -> Alcotest.fail "Incorrect exception was thrown"

let test_exn_lwt_toplevel _ () = lwt_check_raises exn_lwt_toplevel

let test_exn_lwt_internal _ () = lwt_check_raises exn_lwt_internal

let switch = ref None

let test_switch_alloc s () =
  Lwt.return_unit >|= fun () ->
  switch := Some s;
  Alcotest.(check bool)
    "Passed switch is initially on" (Lwt_switch.is_on s) true

let test_switch_dealloc _ () =
  Lwt.return_unit >|= fun () ->
  match !switch with
  | None -> Alcotest.fail "No switch left by `test_switch_alloc` test"
  | Some s ->
      Alcotest.(check bool)
        "Switch is disabled after test" (Lwt_switch.is_on s) false

(* Run it *)
let () =
  let open Alcotest_lwt in
  Lwt_main.run
  @@ run "LwtUtils"
       [
         ( "exceptions",
           [
             test_case_sync "Plain" `Quick test_exn;
             test_case "Lwt toplevel" `Quick test_exn_lwt_toplevel;
             test_case "Lwt internal" `Quick test_exn_lwt_internal;
           ] );
         ( "switches",
           [
             test_case "Allocate resource" `Quick test_switch_alloc;
             test_case "Check resource deallocated" `Quick test_switch_dealloc;
           ] );
       ]
