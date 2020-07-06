open Base

module Service : Admin_sig.SERVICE = struct
  let pages : Admin_model.Page.t list ref = ref []

  let on_bind _ = Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let register_page _ page =
    Logs.debug (fun m ->
        m "ADMIN UI: Registering admin ui page: %s"
          (Admin_model.Page.label page));
    pages :=
      !pages |> List.cons page
      |> List.sort ~compare:(fun p1 p2 ->
             String.compare (Admin_model.Page.path p1)
               (Admin_model.Page.path p2));
    Lwt.return @@ Ok ()

  let get_all_pages _ = Lwt.return @@ Ok !pages
end

let instance =
  Core.Container.create_binding Admin_sig.key (module Service) (module Service)
