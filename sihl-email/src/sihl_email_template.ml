open Lwt.Syntax

module Make (Repo : Sihl_email_template_repo.Sig) : Sihl_contract.Email_template.Sig =
struct
  let get ~id = Repo.get ~id
  let get_by_name ~name = Repo.get_by_name ~name

  let create ~name ~html ~text =
    let template = Sihl_type.Email_template.make ~text ~html name in
    let* () = Repo.insert ~template in
    let id = Sihl_type.Email_template.id template in
    let* created = Repo.get ~id in
    match created with
    | None ->
      Logs.err (fun m ->
          m "EMAIL: Could not create template %a" Sihl_type.Email_template.pp template);
      raise (Sihl_type.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let update ~template =
    let* () = Repo.update ~template in
    let id = Sihl_type.Email_template.id template in
    let* created = Repo.get ~id in
    match created with
    | None ->
      Logs.err (fun m ->
          m "EMAIL: Could not update template %a" Sihl_type.Email_template.pp template);
      raise (Sihl_type.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let render email =
    let template_id = Sihl_type.Email.template_id email in
    let template_data = Sihl_type.Email.template_data email in
    let text_content = Sihl_type.Email.text_content email in
    let html_content = Sihl_type.Email.html_content email in
    let* text_content, html_content =
      match template_id with
      | Some template_id ->
        let* template = Repo.get ~id:template_id in
        let* template =
          match template with
          | None ->
            raise
              (Sihl_type.Email.Exception
                 (Printf.sprintf "Template with id %s not found" template_id))
          | Some template -> Lwt.return template
        in
        Sihl_type.Email_template.render template_data template |> Lwt.return
      | None -> Lwt.return (text_content, html_content)
    in
    email
    |> Sihl_type.Email.set_text_content text_content
    |> Sihl_type.Email.set_html_content html_content
    |> Lwt.return
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()
  let lifecycle = Sihl_core.Container.Lifecycle.create "template" ~start ~stop

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl_core.Container.Service.create lifecycle
  ;;
end
