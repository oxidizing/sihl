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
  let createElement = (~ctx, ()) => {
    let (color, msg) = Admin_context.message(ctx);
    let class_ = ["hero", "is-small", color];
    <section class_ style="margin-top: 2em;">
      <div class_="hero-body"> {Html.txt(msg)} </div>
    </section>;
  };
};

module Layout = {
  let createElement = (~ctx, ~isLoggedIn, ~children, ()) =>
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
      <FlashMessage ctx />
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
  let createElement = (~ctx, ()) => {
    let elems =
      ctx
      |> Admin_context.pages
      |> List.map(~f=page =>
           <li>
             <a href={Admin_page.path(page)}>
               {Html.txt(Admin_page.label(page))}
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
  let createElement = (~ctx, ~title, ~children, ()) => {
    <Layout ctx isLoggedIn=true>
      <div class_="columns">
        <div class_="column is-2 is-desktop"> <Navigation ctx /> </div>
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
  let createElement = (ctx, ()) => {
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

    <Page title="Login">
      <Layout ctx isLoggedIn=false>
        <div class_="columns">
          <div class_="column is-one-quarter" />
          <div class_="column is-two-quarters"> form </div>
          <div class_="column is-one-quarter" />
        </div>
      </Layout>
    </Page>;
  };
};

module DashboardPage = {
  let createElement = (ctx, email) => {
    let welcomeText = "Have a great day, " ++ email;
    <Page title="Dashboard">
      <NavigationLayout ctx title="Dashboard">
        <h1 class_="subtitle"> {Html.txt(welcomeText)} </h1>
      </NavigationLayout>
    </Page>;
  };
};
