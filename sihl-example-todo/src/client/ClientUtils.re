let wrapFormValue = event => {
  let value = ReactEvent.Form.target(event)##value;
  value === "" ? None : Some(value);
};
