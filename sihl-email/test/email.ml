open Alcotest_lwt
open Lwt.Syntax

let create_template _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* template =
    Sihl_facade.Email_template.create ~label:"foo" ~html:"some html" "some text"
  in
  Alcotest.(check string "name" "foo" template.label);
  Alcotest.(check string "has text" "some text" template.text);
  Alcotest.(check (option string) "has html" (Some "some html") template.html);
  Lwt.return ()
;;

let update_template _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* created =
    Sihl_facade.Email_template.create ~label:"foo" ~html:"some html" "some text"
  in
  let updated = Sihl_facade.Email_template.set_label "newname" created in
  let* template = Sihl_facade.Email_template.update updated in
  Alcotest.(check string "label" "newname" template.label);
  Lwt.return ()
;;

let send_simple_email _ () =
  let email =
    Sihl_facade.Email.create
      ~recipient:"recipient@example.com"
      ~sender:"sender@example.com"
      ~subject:"test"
      ~html:"some html"
      "some text"
  in
  let* () = Sihl_facade.Email.send email in
  let sent_email = Sihl_facade.Email.inbox () |> List.hd in
  Alcotest.(
    check string "has recipient" "recipient@example.com" sent_email.recipient);
  Alcotest.(check string "has subject" "test" sent_email.subject);
  Alcotest.(check (option string) "has html" (Some "some html") sent_email.html);
  Alcotest.(check string "has text" "some text" sent_email.text);
  Lwt.return ()
;;

let send_inline_templated_email _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let raw_email =
    Sihl_facade.Email.create
      ~recipient:"recipient@example.com"
      ~sender:"sender@example.com"
      ~subject:"test"
      ~html:"<html>hello {name}, you have signed in {number} of times!</html>"
      "hello {name}, you have signed in {number} of times!"
  in
  let* email =
    Sihl_facade.Email_template.email_of_template
      raw_email
      [ "name", "walter"; "number", "8" ]
  in
  let* () = Sihl_facade.Email.send email in
  let sent_email = Sihl_facade.Email.inbox () |> List.hd in
  let html_rendered =
    "<html>hello walter, you have signed in 8 of times!</html>"
  in
  let text_rendered = "hello walter, you have signed in 8 of times!" in
  Alcotest.(
    check (option string) "has html" (Some html_rendered) sent_email.html);
  Alcotest.(check string "has text" text_rendered sent_email.text);
  Lwt.return ()
;;

let send_templated_email _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let raw_email =
    Sihl_facade.Email.create
      ~sender:"sender@example.com"
      ~recipient:"recipient@example.com"
      ~subject:"test"
      ""
  in
  let* template =
    Sihl_facade.Email_template.create
      ~label:"some template"
      ~html:"<html>hello {name}, you have signed in {number} of times!</html>"
      "hello {name}, you have signed in {number} of times!"
  in
  let* email =
    Sihl_facade.Email_template.email_of_template
      ~template
      raw_email
      [ "name", "walter"; "number", "8" ]
  in
  let* () = Sihl_facade.Email.send email in
  let sent_email = Sihl_facade.Email.inbox () |> List.hd in
  let html_rendered =
    "<html>hello walter, you have signed in 8 of times!</html>"
  in
  let text_rendered = "hello walter, you have signed in 8 of times!" in
  Alcotest.(
    check (option string) "has html" (Some html_rendered) sent_email.html);
  Alcotest.(check string "has text" text_rendered sent_email.text);
  Lwt.return ()
;;

let suite =
  [ ( "email"
    , [ test_case "create email template" `Quick create_template
      ; test_case "update email template" `Quick update_template
      ; test_case "send simple email" `Quick send_simple_email
      ; test_case
          "send inline templated email"
          `Quick
          send_inline_templated_email
      ; test_case "send templated email" `Quick send_templated_email
      ] )
  ]
;;
