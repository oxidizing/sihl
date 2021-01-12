(* The handlers map HTTP responses to HTTP requests.

   Authentication, authorization and input sanitization/validation
   usually happen here. *)

let list req =
  let open Lwt.Syntax in
  let csrf = Sihl.Web.Csrf.find req in
  let notice = Sihl.Web.Flash.find_notice req in
  let alert = Sihl.Web.Flash.find_alert req in
  let* todos, _ = Todo.search 100 in
  Lwt.return @@ Opium.Response.of_html (Template.page csrf todos alert notice)
;;

let list_json _ =
  let open Lwt.Syntax in
  let* todos, _ = Todo.search 100 in
  let todos = `List (Caml.List.map Todo.to_yojson todos) in
  Lwt.return @@ Opium.Response.of_json todos
;;

let add req =
  let open Lwt.Syntax in
  match Sihl.Web.Form.find_all req with
  | [ ("description", [ description ]) ] ->
    let* _ = Todo.create description in
    let resp = Opium.Response.redirect_to "/" in
    Lwt.return @@ Sihl.Web.Flash.set_notice (Some "Successfully updated") resp
  | _ ->
    let resp = Opium.Response.redirect_to "/" in
    Lwt.return @@ Sihl.Web.Flash.set_alert (Some "Failed to update todo description") resp
;;

let do_ req =
  let open Lwt.Syntax in
  match Sihl.Web.Form.find_all req with
  | [ ("id", [ id ]) ] ->
    let* todo = Todo.find_opt id in
    (match todo with
    | None ->
      let resp = Opium.Response.redirect_to "/" in
      Lwt.return @@ Sihl.Web.Flash.set_alert (Some "Todo not found") resp
    | Some todo ->
      let* () = Todo.do_ todo in
      let resp = Opium.Response.redirect_to "/" in
      Lwt.return @@ Sihl.Web.Flash.set_notice (Some "Successfully set to done") resp)
  | _ ->
    let resp = Opium.Response.redirect_to "/" in
    Lwt.return @@ Sihl.Web.Flash.set_alert (Some "Failed to set to-do to done") resp
;;
