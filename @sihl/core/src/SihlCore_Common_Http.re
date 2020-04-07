module Async = SihlCore_Common_Async;

let parseAuthToken = header => {
  let parts = header |> Js.String.split(" ") |> Belt.Array.reverse;
  Belt.Array.get(parts, 0);
};

type endpoint = {
  use: Express.App.t => unit,
  useOnRouter: Express.Router.t => unit,
};

// TODO find a better place
type command('a) = {
  name: string,
  description: string,
  f: ('a, list(string), string) => Async.t(unit),
};
