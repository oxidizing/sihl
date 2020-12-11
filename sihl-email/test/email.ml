open Alcotest_lwt
open Lwt.Syntax

let create_template _ () =
  let* () = Sihl_persistence.Repository.clean_all () in
  let* created =
    Sihl_facade.Email_template.create ~name:"foo" ~html:"some html" ~text:"some text"
  in
  let id = Sihl_contract.Email_template.id created in
  let* template =
    Sihl_facade.Email_template.get ~id
    |> Lwt.map (Option.to_result ~none:"Template not found")
    |> Lwt.map Result.get_ok
  in
  Alcotest.(check string "name" "foo" template.Sihl_contract.Email_template.name);
  Alcotest.(
    check string "txt" "some text" (Sihl_contract.Email_template.content_text template));
  Alcotest.(
    check string "txt" "some html" (Sihl_contract.Email_template.content_html template));
  Lwt.return ()
;;

let update_template _ () =
  let* () = Sihl_persistence.Repository.clean_all () in
  let* created =
    Sihl_facade.Email_template.create ~name:"foo" ~html:"some html" ~text:"some text"
  in
  let updated = Sihl_contract.Email_template.set_name "newname" created in
  let* template = Sihl_facade.Email_template.update ~template:updated in
  Alcotest.(check string "name" "newname" template.Sihl_contract.Email_template.name);
  Lwt.return ()
;;

let suite =
  [ ( "email"
    , [ test_case "create email template" `Quick create_template
      ; test_case "update email template" `Quick update_template
      ] )
  ]
;;
