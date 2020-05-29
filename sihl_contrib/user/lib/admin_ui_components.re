open Base;
open Tyxml;

let stylesheet_uri = "https://cdnjs.cloudflare.com/ajax/libs/bulma/0.8.0/css/bulma.min.css";

module Empty = {
  let createElement = () => <div />;
};

module Page = {
  let createElement = (~title, ~children, ()) =>
    <html>
      <head>
        <title> {Html.txt(title)} </title>
        <link rel="stylesheet" href={Html.uri_of_string(stylesheet_uri)} />
      </head>
      <body> ...children </body>
    </html>;
};

module Logout = {
  let createElement = () =>
    <form action="/admin/logout/" method="Post">
      <button class_="button is-danger is-pulled-right"> "Logout" </button>
    </form>;
};

module FlashMessage = {
  type message =
    | Success(string)
    | Warning(string)
    | Error(string);

  let extract = color =>
    switch (color) {
    | Success(msg) => ("is-success", msg)
    | Warning(msg) => ("is-warning", msg)
    | Error(msg) => ("is-danger", msg)
    };

  let createElement = (~message, ()) => {
    let (color, msg) = extract(message);
    let class_ = ["hero", "is-small", color];
    <section class_ style="margin-top: 2em;">
      <div class_="hero-body"> {Html.txt(msg)} </div>
    </section>;
  };
};

module Layout = {
  let createElement = (~message, ~isLoggedIn, ~children, ()) =>
    <div>
      <section class_="hero is-small is-primary is-bold">
        <div class_="hero-body">
          {isLoggedIn ? <Logout /> : <Empty />}
          <div class_="container is-pulled-left">
            <h1 class_="title"> "Sihl" </h1>
            <h2 class_="subtitle"> "Admin UI" </h2>
          </div>
        </div>
      </section>
      <FlashMessage message />
      <section class_="section" style="min-height: 40em;">
        ...children
      </section>
      <footer class_="footer">
        <div class_="content has-text-centered">
          <p> "by Oxidizing Systems | v1.0.0" </p>
        </div>
      </footer>
    </div>;
};

module Navigation = {
  let createElement = (~pages, ()) => {
    let elems =
      pages
      |> List.map(~f=page =>
           <li>
             <a href={Admin_ui.Page.path(page)}>
               {Html.txt(Admin_ui.Page.label(page))}
             </a>
           </li>
         );
    <aside class_="menu">
      <p class_="menu-label"> "General" </p>
      <ul class_="menu-list"> ...elems </ul>
    </aside>;
  };
};

module NavigationLayout = {
  let createElement = (~message, ~title, ~pages, ~children, ()) => {
    <Layout message isLoggedIn=true>
      <div class_="columns">
        <div class_="column is-2 is-desktop"> <Navigation pages /> </div>
        <div class_="column is-10">
          ...{List.cons(
            <h1 class_="title"> {Html.txt(title)} </h1>,
            children,
          )}
        </div>
      </div>
    </Layout>;
  };
};

module LoginPage = {
  let createElement = (~message, ()) => {
    let form =
      <form action="/admin/login/" method="Post">
        <div class_="field">
          <label class_="label"> "Email Address" </label>
          <div class_="control">
            <input class_="input" name="email" type_="Email" />
          </div>
        </div>
        <div class_="field">
          <label class_="label"> "Password" </label>
          <div class_="control">
            <input class_="input" name="password" type_="Password" />
          </div>
        </div>
        <div class_="field">
          <div class_="control">
            <button class_="button is-link" type_="Submit"> "Submit" </button>
          </div>
        </div>
      </form>;

    <Page title="login">
      <Layout message isLoggedIn=false>
        <div class_="columns">
          <div class_="column is-one-quarter" />
          <div class_="column is-two-quarters"> form </div>
        </div>
        <div class_="column is-one-quarter" />
      </Layout>
    </Page>;
  };
};

module DashboardPage = {
  let createElement = (~pages, ~message, ~user, ()) => {
    let welcomeText = "Have a great day, " ++ Model.User.email(user);
    <Page title="Dashbpard">
      <NavigationLayout pages message title="Dashboard">
        <h1 class_="subtitle"> {Html.txt(welcomeText)} </h1>
      </NavigationLayout>
    </Page>;
  };
};
