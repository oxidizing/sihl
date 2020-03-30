module Async = SihlCoreAsync;

module Nodemailer = {
  module Email = {
    [@bs.deriving abstract]
    type t = {
      from: string,
      [@bs.as "to"]
      to_: string,
      [@bs.optional]
      bcc: string,
      [@bs.optional]
      subject: string,
      [@bs.optional]
      text: string,
      [@bs.optional]
      html: string,
    };

    let make = t;
  };

  module Config = {
    type auth = {
      .
      "user": string,
      "pass": string,
    };

    [@bs.deriving abstract]
    type t = {
      host: string,
      port: int,
      secure: bool,
      pool: bool,
      [@bs.optional]
      auth,
    };

    let make = t;
  };

  module Transport = {
    type t;
    [@bs.module "nodemailer"]
    external create: Config.t => t = "createTransport";
    [@bs.send] external send: (t, Email.t) => Js.Promise.t(unit) = "sendMail";
    [@bs.send] external verify: t => Js.Promise.t(unit) = "verify";

    let make = (~host, ~port, ~secure, ~auth, ~pool, ()) => {
      Config.make(~host, ~port, ~secure, ~auth, ~pool, ()) |> create;
    };
  };
};

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

let devInbox: Pervasives.ref(option(t)) = ref(None);

let getLastEmail = () => devInbox^;

let send = email =>
  if (SihlCoreConfig.get(~default="console", "EMAIL_BACKEND") === "smtp") {
    let email =
      Nodemailer.Email.make(
        ~from=email.sender,
        ~to_=email.recipient,
        ~text=email.text,
        (),
      );
    let transport =
      Nodemailer.Transport.make(
        ~host=SihlCoreConfig.get("SMTP_HOST"),
        ~port=SihlCoreConfig.getInt("SMTP_PORT"),
        ~auth={
          "user": SihlCoreConfig.get("SMTP_AUTH_USERNAME"),
          "pass": SihlCoreConfig.get("SMTP_AUTH_PASSWORD"),
        },
        ~secure=SihlCoreConfig.getBool("SMTP_SECURE"),
        ~pool=SihlCoreConfig.getBool("SMTP_POOL"),
        (),
      );
    Nodemailer.Transport.send(transport, email);
  } else {
    devInbox := Some(email);
    Async.async @@ SihlCoreLog.info(toString(email), ());
  };
