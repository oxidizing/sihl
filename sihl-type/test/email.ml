let test_email_rendering_simple _ () =
  let data =
    Sihl_type.Email_template.Data.empty
    |> Sihl_type.Email_template.Data.add ~key:"foo" ~value:"bar"
  in
  let actual, _ =
    Sihl_type.Email_template.render
      data
      (Sihl_type.Email_template.make ~text:"{foo}" "test")
  in
  Alcotest.(check string) "Renders template" "bar" actual;
  let data =
    Sihl_type.Email_template.Data.empty
    |> Sihl_type.Email_template.Data.add ~key:"foo" ~value:"hey"
    |> Sihl_type.Email_template.Data.add ~key:"bar" ~value:"ho"
  in
  let actual, _ =
    Sihl_type.Email_template.render
      data
      (Sihl_type.Email_template.make ~text:"{foo} {bar}" "test")
  in
  Lwt.return @@ Alcotest.(check string) "Renders template" "hey ho" actual
;;

let test_email_rendering_complex _ () =
  let data =
    Sihl_type.Email_template.Data.empty
    |> Sihl_type.Email_template.Data.add ~key:"foo" ~value:"hey"
    |> Sihl_type.Email_template.Data.add ~key:"bar" ~value:"ho"
  in
  let actual, _ =
    Sihl_type.Email_template.render
      data
      (Sihl_type.Email_template.make ~text:"{foo} {bar}{foo}" "test")
  in
  Lwt.return @@ Alcotest.(check string) "Renders template" "hey hohey" actual
;;

let suite =
  Alcotest_lwt.
    [ ( "email"
      , [ test_case "render email simple" `Quick test_email_rendering_simple
        ; test_case "render email complex" `Quick test_email_rendering_complex
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "email" suite)
;;
