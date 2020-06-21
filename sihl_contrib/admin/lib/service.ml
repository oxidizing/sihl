open Base

let pages : Sihl.Admin.Page.t list ref = ref []

let on_bind _ = Lwt.return @@ Ok ()

let on_start _ = Lwt.return @@ Ok ()

let on_stop _ = Lwt.return @@ Ok ()

let register_page page =
  Logs.debug (fun m ->
      m "ADMIN UI: Registering admin ui page: %s" (Sihl.Admin.Page.label page));
  pages :=
    !pages |> List.cons page
    |> List.sort ~compare:(fun p1 p2 ->
           String.compare (Sihl.Admin.Page.path p1) (Sihl.Admin.Page.path p2));
  ()

let get_all_pages () = !pages
