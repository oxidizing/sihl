module Async = Sihl.Core.Async;

module Board = ClientBoardPage;
module Register = ClientRegisterPage;
module Login = ClientLoginPage;

module Route = {
  [@react.component]
  let make = () => {
    let url = ReasonReactRouter.useUrl();
    switch (url.path) {
    | ["app", "login"] => <Login />
    | ["app", "register"] => <Register />
    | ["app", "boards", ..._] => <Board />
    | _ => <Login />
    };
  };
};

module Main = {
  [@react.component]
  let make = (~children) => {
    let (error, setError) = React.useState(_ => None);
    let (message, setMessage) = React.useState(_ => None);

    <ClientContextProvider.Message value=(message, setMessage)>
      <ClientContextProvider.Error value=(error, setError)>
        <ClientNotification.Error />
        <ClientNotification.Message />
        children
      </ClientContextProvider.Error>
    </ClientContextProvider.Message>;
  };
};

ReactDOMRe.renderToElementWithId(<Main> <Route /> </Main>, "app");
