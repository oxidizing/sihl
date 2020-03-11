module Error = {
  [@react.component]
  let make = () => {
    let (error, setError) =
      React.useContext(ClientContextProvider.Error.context);

    switch (error) {
    | Some(text) =>
      <div className="container is-global-message">
        <div className="notification is-danger">
          <button className="delete" onClick={_ => setError(_ => None)} />
          {React.string(text)}
        </div>
      </div>
    | _ => React.null
    };
  };
};

module Message = {
  [@react.component]
  let make = () => {
    let (message, setMessage) =
      React.useContext(ClientContextProvider.Message.context);

    React.useEffect(() => {
      let timer = Js.Global.setTimeout(() => setMessage(_ => None), 4000);
      Some(() => Js.Global.clearTimeout(timer));
    });

    switch (message) {
    | Some(text) =>
      <div className="container is-global-message">
        <div className="notification is-success">
          <button className="delete" onClick={_ => setMessage(_ => None)} />
          {React.string(text)}
        </div>
      </div>
    | _ => React.null
    };
  };
};
