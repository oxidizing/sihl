let test_email_rendering_simple () =
  let data = [ "foo", "bar" ] in
  let actual, _ = Sihl_facade.Email_template.render data "{foo}" None in
  Alcotest.(check string) "Renders template" "bar" actual;
  let data = [ "foo", "hey"; "bar", "ho" ] in
  let actual, _ = Sihl_facade.Email_template.render data "{foo} {bar}" None in
  Alcotest.(check string) "Renders template" "hey ho" actual
;;

let test_email_rendering_complex () =
  let data = [ "foo", "hey"; "bar", "ho" ] in
  let actual, _ =
    Sihl_facade.Email_template.render data "{foo} {bar}{foo}" None
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
;;

let suite =
  Alcotest.
    [ ( "email"
      , [ test_case "render simple" `Quick test_email_rendering_simple
        ; test_case "render complex" `Quick test_email_rendering_complex
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Alcotest.run "template" suite
;;
