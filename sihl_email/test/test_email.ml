let test_email_rendering_simple () =
  let actual =
    Sihl_email.Service.render [ ("foo", "bar") ]
      (Sihl_email.Model.Template.create ~label:"test" ~value:"{foo}")
  in
  let _ = Alcotest.(check string) "Renders template" "bar" actual in
  let actual =
    Sihl_email.Service.render
      [ ("foo", "hey"); ("bar", "ho") ]
      (Sihl_email.Model.Template.create ~label:"test" ~value:"{foo} {bar}")
  in
  Alcotest.(check string) "Renders template" "hey ho" actual

let test_email_rendering_complex () =
  let actual =
    Sihl_email.Service.render
      [ ("foo", "hey"); ("bar", "ho") ]
      (Sihl_email.Model.Template.create ~label:"test" ~value:"{foo} {bar}{foo}")
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
