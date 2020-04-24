let parseAuthToken = header => {
  let parts = header |> Js.String.split(" ") |> Belt.Array.reverse;
  Belt.Array.get(parts, 0);
};

type endpoint = {
  use: Express.App.t => unit,
  useOnRouter: Express.Router.t => unit,
};
