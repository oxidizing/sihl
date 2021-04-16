let sanity_check () =
  let expected = 5 in
  let actual = 2 + 3 in
  Alcotest.(check int "is same" expected actual)
;;

let suite = Alcotest.[ "canary test", [ test_case "2 + 3 = 5" `Quick sanity_check ] ]

let () =
  Unix.putenv "SIHL_ENV" "test";
  Alcotest.(run "unit" suite)
;;
