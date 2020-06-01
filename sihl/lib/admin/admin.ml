module Component = Admin_component
module Page = Admin_page
module Context = Admin_context

let register_page = Context.Store.register

let get_all = Context.Store.get_all

type 'a admin_page = 'a Admin_context.admin_page

let render context admin_page args =
  let admin_context = Context.of_template_context context in
  let document = admin_page admin_context args in
  Template.render document
