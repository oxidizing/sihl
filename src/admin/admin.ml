open Base
module Sig = Admin_sig
module Service = Admin_service
module Component = Admin_component
module Page = Admin_core.Page

let register_page ctx page =
  match Core.Container.fetch_service Admin_sig.key with
  | Some (module Service : Admin_sig.SERVICE) -> Service.register_page ctx page
  | None ->
      Logs.warn (fun m ->
          m
            "ADMIN: Could not register admin page, have you installed the \
             admin service?");
      Lwt.return @@ Ok ()

let register_pages ctx pages =
  pages
  |> List.map ~f:(register_page ctx)
  |> Lwt.all |> Lwt.map Result.all |> Lwt_result.map ignore

let get_all_pages ctx =
  match Core.Container.fetch_service Admin_sig.key with
  | Some (module Service : Admin_sig.SERVICE) -> Service.get_all_pages ctx
  | None ->
      Logs.warn (fun m ->
          m
            "ADMIN: Could not get admin pages, have you installed the admin \
             app?");
      Lwt.return @@ Ok []

let create_page = Page.create
