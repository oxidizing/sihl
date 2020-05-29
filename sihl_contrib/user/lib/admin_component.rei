open Tyxml;

module Empty: {let createElement: unit => Html.elt([> Html_types.div]);};
module Page: {
  let createElement:
    (
      ~title: string,
      ~children: list(Html.elt([< Html_types.flow5])),
      unit
    ) =>
    Html.elt([> Html_types.html]);
};
module Logout: {let createElement: unit => Html.elt([> Html_types.form]);};
module FlashMessage: {
  let createElement:
    (~ctx: Sihl.Admin.Context.t, unit) => Html.elt([> Html_types.section]);
};
module Layout: {
  let createElement:
    (
      ~ctx: Sihl.Admin.Context.t,
      ~isLoggedIn: bool,
      ~children: list(Html.elt([< Html_types.section_content_fun])),
      unit
    ) =>
    Html.elt([> Html_types.div]);
};
module Navigation: {
  let createElement:
    (~ctx: Sihl.Admin.Context.t, unit) => Html.elt([> Html_types.aside]);
};
module NavigationLayout: {
  let createElement:
    (
      ~ctx: Sihl.Admin.Context.t,
      ~title: string,
      ~children: list(Html.elt([< Html_types.div_content_fun > `H1])),
      unit
    ) =>
    Html.elt([> Html_types.div]);
};

module LoginPage: {let createElement: Sihl.Admin.admin_page(unit);};

module DashboardPage: {let createElement: Sihl.Admin.admin_page(Model.User.t);
};
