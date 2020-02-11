let flushBufferTimeoutMs = 50;

let stdOutStrategy = toLog =>
  toLog |> Belt.List.toArray |> Js.Array.joinWith("\n") |> Js.log;

let buffer = ref([]);
let flushBufferTimer = ref(None);
let flushStrategies: Pervasives.ref(list(list(string) => unit)) =
  ref([stdOutStrategy]);

let flushBuffer = (buffer, strategies) => {
  let _ = Belt.List.map(strategies^, strategy => strategy(buffer^));
  buffer := [];
  ();
};

let addStrategy = strategy =>
  flushStrategies := Belt.List.add(flushStrategies^, strategy);

// console.* methods are synchronous and they block the node event loop
// We implement async logging by flushing a log buffer
let scheduleAsyncLog = flushBufferTimer => {
  switch (flushBufferTimer^) {
  | Some(timerId) =>
    Js.Global.clearTimeout(timerId);
    flushBufferTimer :=
      Some(
        Js.Global.setTimeout(
          () => flushBuffer(buffer, flushStrategies),
          flushBufferTimeoutMs,
        ),
      );
  | None =>
    flushBufferTimer :=
      Some(
        Js.Global.setTimeout(
          () => flushBuffer(buffer, flushStrategies),
          flushBufferTimeoutMs,
        ),
      )
  };
};

// Evaluate pattern where usage looks like Log.info(m => m("foo %s", "bar"))
// in order to use the inference mechanism for different arities

let log = (level, content, ~path, ~id) => {
  let date = Js.Date.make() |> Js.Date.toISOString;
  let toLog =
    switch (path, id) {
    | (Some(path), Some(id)) =>
      date ++ " - " ++ level ++ id ++ path ++ " - " ++ content
    | _ => date ++ " - " ++ level ++ " - " ++ content
    };
  buffer := Belt.List.add(buffer^, toLog);
  scheduleAsyncLog(flushBufferTimer);
};

let info = (~path=?, ~id=?, str, ()) => log("INFO", str, ~path, ~id);
let warn = (~path=?, ~id=?, str, ()) => log("WARN", str, ~path, ~id);
let error = (~path=?, ~id=?, str, ()) => log("ERROR", str, ~path, ~id);
