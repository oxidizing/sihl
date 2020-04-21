let test_email_rendering () =
  let actual = Sihl_core.Email.render [ ("foo", "bar") ] "{foo}" in
  let _ = Alcotest.(check string) "Renders template" "bar" actual in
  let actual =
    Sihl_core.Email.render [ ("foo", "hey"); ("bar", "ho") ] "{foo} {bar}"
  in
  let _ = Alcotest.(check string) "Renders template" "hey ho" actual in
  let actual =
    Sihl_core.Email.render [ ("foo", "hey"); ("bar", "ho") ] "{foo} {bar}{foo}"
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
