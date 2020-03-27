let parseAuthToken = header => {
  let parts = header |> Js.String.split(" ") |> Belt.Array.reverse;
  Belt.Array.get(parts, 0);
};
