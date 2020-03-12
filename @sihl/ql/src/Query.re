module Error = {
  type t =
    | InvalidString
    | InvalidCondition(string);

  let eval: t => string =
    error =>
      switch (error) {
      | InvalidString => "invalid string provided"
      | InvalidCondition(msg) => "invalid condition found at " ++ msg
      };
};

type op =
  | Lt
  | Lte
  | Gt
  | Gte
  | Eq
  | Like;
type condition =
  | StringCondition(op, string, string)
  | IntCondition(op, int, int);
type t = list(condition);
