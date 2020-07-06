open Base

module Context = struct
  type t = { flash : Message.t option; csrf : string }

  let create ~flash () = { flash; csrf = "TODO" }

  let flash ctx = ctx.flash

  let csrf ctx = ctx.csrf
end

module Document = struct
  type t = Tyxml_html.doc
end

let render page = Caml.Format.asprintf "%a" (Tyxml.Html.pp ()) page

let context = Context.create
