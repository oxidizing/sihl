module Context = struct
  type t = { csrf : string }

  let create () = { csrf = "TODO" }
  let csrf ctx = ctx.csrf
end

module Document = struct
  type t = Tyxml_html.doc
end

let render page = Caml.Format.asprintf "%a" (Tyxml.Html.pp ()) page
let context = Context.create
