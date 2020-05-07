let test_email_rendering_simple () =
  let actual = Sihl_email.Email.render [ ("foo", "bar") ] "{foo}" in
  let _ = Alcotest.(check string) "Renders template" "bar" actual in
  let actual =
    Sihl_email.Email.render [ ("foo", "hey"); ("bar", "ho") ] "{foo} {bar}"
  in
  Alcotest.(check string) "Renders template" "hey ho" actual

let test_email_rendering_complex () =
  let actual =
    Sihl_email.Email.render [ ("foo", "hey"); ("bar", "ho") ] "{foo} {bar}{foo}"
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
