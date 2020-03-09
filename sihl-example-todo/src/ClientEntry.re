module Main = {
  [@react.component]
  let make = () => <span> {React.string("Hello world")} </span>;
};

ReactDOMRe.renderToElementWithId(<Main />, "app");
