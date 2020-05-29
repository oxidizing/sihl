open Base

module Page = struct
  type t = { path : string; label : string }

  let path page = page.path

  let label page = page.label

  let create ~path ~label = { path; label }
end

(* Move into Admin UI app and make a repo out of it *)
module Store = struct
  let pages : Page.t list ref = ref []

  let register page =
    Logs.debug (fun m ->
        m "ADMIN UI: Registering admin ui page: %s" (Page.label page));
    pages :=
      !pages |> List.cons page
      |> List.sort ~compare:(fun p1 p2 ->
             String.compare (Page.path p1) (Page.path p2));
    ()

  let get_all () = !pages
end

let register_page = Store.register

let get_all = Store.get_all

module Context = struct
  type t = { template_context : Template.Context.t; pages : Page.t list }

  let message _ = ("TODO", "TODO")

  let pages ctx = ctx.pages

  let of_template_context template_context = { template_context; pages = [] }
end

type 'a admin_page = Context.t -> 'a -> Template.Document.t

let render context admin_page args =
  let admin_context = Context.of_template_context context in
  let document = admin_page admin_context args in
  Template.render document
