open Alcotest_lwt
open Lwt.Syntax

module Make (EmailTemplateService : Sihl.Email.Sig.TEMPLATE_SERVICE) = struct
  let create_template _ () =
    let* () = Sihl.Repository.Service.clean_all () in
    let* created =
      EmailTemplateService.create ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let id = Sihl.Email.Template.id created in
    let* template =
      EmailTemplateService.get ~id
      |> Lwt.map (Option.to_result ~none:"Template not found")
      |> Lwt.map Result.get_ok
    in
    Alcotest.(check string "name" "foo" (Sihl.Email.Template.name template));
    Alcotest.(check string "txt" "some text" (Sihl.Email.Template.content_text template));
    Alcotest.(check string "txt" "some html" (Sihl.Email.Template.content_html template));
    Lwt.return ()
  ;;

  let update_template _ () =
    let* () = Sihl.Repository.Service.clean_all () in
    let* created =
      EmailTemplateService.create ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let updated = Sihl.Email.Template.set_name "newname" created in
    let* template = EmailTemplateService.update ~template:updated in
    Alcotest.(check string "name" "newname" (Sihl.Email.Template.name template));
    Lwt.return ()
  ;;

  let test_suite =
    ( "email"
    , [ test_case "create email template" `Quick create_template
      ; test_case "update email template" `Quick update_template
      ] )
  ;;
end
