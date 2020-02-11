module V4 = {
  [@bs.module] external ex_uuidv4: unit => string = "uuid/v4";
  let uuidv4 = ex_uuidv4;
  let isValid = uuid =>
    Js.String.match(
      [%bs.re
        "/^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/i"
      ],
      uuid,
    )
    ->Belt.Option.map(_ => true)
    ->Belt.Option.getWithDefault(false);
};
