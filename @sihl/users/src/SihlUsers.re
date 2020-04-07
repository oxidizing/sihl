module User = SihlUsers_Service.User;
module Seeds = SihlUsers_Seeds;
module App = SihlUsers_App;
module AdminUi = {
  module NavigationLayout = SihlUsers_AdminUi.NavigationLayout;
  module Page = SihlUsers_AdminUi.Page;
  let render = SihlUsers_AdminUi.HtmlTemplate.render;
  let pages = SihlUsers_AdminUi.State.pages^;
};
