open Alcotest_lwt
open Lwt.Syntax

module Make (EmailTemplateService : Sihl_contract.Email_template.Sig) = struct
  let create_template _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* created =
      EmailTemplateService.create ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let id = Sihl_type.Email_template.id created in
    let* template =
      EmailTemplateService.get ~id
      |> Lwt.map (Option.to_result ~none:"Template not found")
      |> Lwt.map Result.get_ok
    in
    Alcotest.(check string "name" "foo" (Sihl_type.Email_template.name template));
    Alcotest.(
      check string "txt" "some text" (Sihl_type.Email_template.content_text template));
    Alcotest.(
      check string "txt" "some html" (Sihl_type.Email_template.content_html template));
    Lwt.return ()
  ;;

  let update_template _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* created =
      EmailTemplateService.create ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let updated = Sihl_type.Email_template.set_name "newname" created in
    let* template = EmailTemplateService.update ~template:updated in
    Alcotest.(check string "name" "newname" (Sihl_type.Email_template.name template));
    Lwt.return ()
  ;;

  let suite =
    [ ( "email"
      , [ test_case "create email template" `Quick create_template
        ; test_case "update email template" `Quick update_template
        ] )
    ]
  ;;
end
