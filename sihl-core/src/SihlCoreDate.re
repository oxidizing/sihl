let unixMs = Js.Date.now;
let unixSeconds = () => Js.Math.round(Js.Date.now() /. 1000.0);
let fromFloat = Js.Date.fromFloat;
let toISOString = Js.Date.toISOString;
let today = () =>
  Js.Date.make()
  |> Js.Date.toISOString
  |> Js.String.split("T")
  |> Belt.List.fromArray
  |> Belt.List.head;
let isValidDate: Js.Date.t => bool = [%raw
  {| function f(d) { return d instanceof Date && !isNaN(d); } |}
];
let isValidString = str => str |> Js.Date.fromString |> isValidDate;
let millis = date => date |> Js.Date.getTime;
let millisFromString = str => str |> Js.Date.fromString |> millis;
