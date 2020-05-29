open Base

module Page = struct
  type t = { path : string; label : string }

  let path page = page.path

  let label page = page.label

  let create ~path ~label = { path; label }
end

module Store = struct
  let pages : Page.t list ref = ref []

  let register page =
    Logs.info (fun m -> m "registering admin ui page: %s" (Page.label page));
    pages :=
      !pages |> List.cons page
      |> List.sort ~compare:(fun p1 p2 ->
             String.compare (Page.path p1) (Page.path p2));
    ()

  let get_all () = !pages
end

let register_page = Store.register

let render page = Caml.Format.asprintf "%a" (Tyxml.Html.pp ()) page
