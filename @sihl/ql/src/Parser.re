type output = Belt.Result.t(Query.t, Query.Error.t);

let parse: string => output =
  str =>
    switch (str) {
    | "" => Belt.Result.Ok([])
    | _ => Belt.Result.Error(InvalidString)
    };
