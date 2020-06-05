let test_email_rendering_simple () =
  let actual =
    Sihl_email.Model.Email.render [ ("foo", "bar") ]
      (Sihl_email.Model.Template.create ~text:"{foo}" "test")
  in
  let _ = Alcotest.(check string) "Renders template" "bar" actual in
  let actual =
    Sihl_email.Model.Email.render
      [ ("foo", "hey"); ("bar", "ho") ]
      (Sihl_email.Model.Template.create ~text:"{foo} {bar}" "test")
  in
  Alcotest.(check string) "Renders template" "hey ho" actual

let test_email_rendering_complex () =
  let actual =
    Sihl_email.Model.Email.render
      [ ("foo", "hey"); ("bar", "ho") ]
      (Sihl_email.Model.Template.create ~text:"{foo} {bar}{foo}" "test")
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
