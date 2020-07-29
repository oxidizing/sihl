let test_email_rendering_simple _ () =
  let data =
    Sihl.Email.Template.Data.empty
    |> Sihl.Email.Template.Data.add ~key:"foo" ~value:"bar"
  in
  let actual, _ =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo}" "test")
  in
  Alcotest.(check string) "Renders template" "bar" actual;
  let data =
    Sihl.Email.Template.Data.empty
    |> Sihl.Email.Template.Data.add ~key:"foo" ~value:"hey"
    |> Sihl.Email.Template.Data.add ~key:"bar" ~value:"ho"
  in
  let actual, _ =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo} {bar}" "test")
  in
  Lwt.return @@ Alcotest.(check string) "Renders template" "hey ho" actual

let test_email_rendering_complex _ () =
  let data =
    Sihl.Email.Template.Data.empty
    |> Sihl.Email.Template.Data.add ~key:"foo" ~value:"hey"
    |> Sihl.Email.Template.Data.add ~key:"bar" ~value:"ho"
  in
  let actual, _ =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo} {bar}{foo}" "test")
  in
  Lwt.return @@ Alcotest.(check string) "Renders template" "hey hohey" actual
