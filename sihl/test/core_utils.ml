let ptime =
  Alcotest.of_pp (fun ppf ptime ->
      Format.fprintf ppf "%s" (Ptime.to_rfc3339 ptime))
;;

let parse_ptime _ () =
  let expected = Ptime.of_date (2020, 1, 1) |> Option.get |> Result.ok in
  let actual = Sihl.Time.ptime_of_date_string "2020-01-01" in
  Alcotest.(check (result ptime string) "parses string" expected actual);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.[ "utils", [ test_case "parse ptime" `Quick parse_ptime ] ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "utils" suite)
;;
