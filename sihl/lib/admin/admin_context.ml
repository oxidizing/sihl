open Base
module Page = Admin_page

type t = { template_context : Template.Context.t; pages : Page.t list }

type 'a admin_page = t -> 'a -> Template.Document.t

let message ctx =
  match ctx.template_context |> Template.Context.flash with
  | Some (Success msg) -> Some ("is-success", msg)
  | Some (Warning msg) -> Some ("is-alert", msg)
  | Some (Error msg) -> Some ("is-danger", msg)
  | None -> None

let pages ctx = ctx.pages

let of_template_context template_context =
  let pages = Admin_bind.Service.get_all_pages () in
  { template_context; pages }
