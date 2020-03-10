let defaultMessage: option(string) = None;
let defaultSetMessage: (option(string) => option(string)) => unit = _ => ();

module Error = {
  let context = React.createContext((defaultMessage, defaultSetMessage));

  let makeProps = (~value, ~children, ()) => {
    "value": value,
    "children": children,
  };

  let make = React.Context.provider(context);
};

module Message = {
  let context = React.createContext((defaultMessage, defaultSetMessage));

  let makeProps = (~value, ~children, ()) => {
    "value": value,
    "children": children,
  };

  let make = React.Context.provider(context);
};
