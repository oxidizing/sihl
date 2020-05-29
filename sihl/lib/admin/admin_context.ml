open Base
module Page = Admin_page

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

type t = { template_context : Template.Context.t; pages : Page.t list }

type 'a admin_page = t -> 'a -> Template.Document.t

let message _ = ("TODO", "TODO")

let pages ctx = ctx.pages

let of_template_context template_context =
  { template_context; pages = Store.get_all () }
