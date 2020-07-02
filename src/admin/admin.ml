module Component = Admin_component
module Page = Admin_model.Page

let render _ _ _ = failwith "TODO render()"

(* let admin_context = Context.of_template_context context in
 * let document = admin_page admin_context args in
 * Template.render document *)

let register_page ctx page =
  match Core.Container.fetch_service Admin_sig.key with
  | Some (module Service : Admin_sig.SERVICE) -> Service.register_page ctx page
  | None ->
      Logs.warn (fun m ->
          m
            "ADMIN: Could not register admin page, have you installed the \
             admin app?");
      Lwt.return @@ Ok ()

let get_all_pages ctx =
  match Core.Container.fetch_service Admin_sig.key with
  | Some (module Service : Admin_sig.SERVICE) -> Service.get_all_pages ctx
  | None ->
      Logs.warn (fun m ->
          m
            "ADMIN: Could not get admin pages, have you installed the admin \
             app?");
      Lwt.return @@ Ok []

let create_page _ = failwith "TODO implement admin create_page"
