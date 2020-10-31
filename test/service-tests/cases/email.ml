open Alcotest_lwt
open Lwt.Syntax

module Make (EmailTemplateService : Sihl.Email.Sig.TEMPLATE_SERVICE) = struct
  let create_template _ () =
    let ctx = Sihl.Core.Ctx.create () in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let* created =
      EmailTemplateService.create ctx ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let id = Sihl.Email.Template.id created in
    let* template =
      EmailTemplateService.get ctx ~id
      |> Lwt.map (Option.to_result ~none:"Template not found")
      |> Lwt.map Result.get_ok
    in
    Alcotest.(check string "name" "foo" (Sihl.Email.Template.name template));
    Alcotest.(check string "txt" "some text" (Sihl.Email.Template.content_text template));
    Alcotest.(check string "txt" "some html" (Sihl.Email.Template.content_html template));
    Lwt.return ()
  ;;

  let update_template _ () =
    let ctx = Sihl.Core.Ctx.create () in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let* created =
      EmailTemplateService.create ctx ~name:"foo" ~html:"some html" ~text:"some text"
    in
    let updated = Sihl.Email.Template.set_name "newname" created in
    let* template = EmailTemplateService.update ctx ~template:updated in
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
