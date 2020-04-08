type t = {
  sender: string,
  subject: string,
  recipient: string,
  text: string,
};

let make = (~sender, ~recipient, ~subject, ~text) => {
  {sender, subject, recipient, text};
};

let toString = email => {
  let sender = email.sender;
  let subject = email.subject;
  let recipient = email.recipient;
  let text = email.text;
  {j|
---------------------------
Email sent by: $(sender)
Recipient: $(recipient)
Subject: $(subject)

$(text)
---------------------------
|j};
};

let replaceElement = (text, key, value) => {
  let re = Js.Re.fromStringWithFlags("{" ++ key ++ "}", ~flags="g");
  Js.String.replaceByRe(re, value, text);
};

let rec render = (template, data) =>
  switch (data) {
  | [] => template
  | [(key, value), ...rest] =>
    render(replaceElement(template, key, value), rest)
  };
