open Tyxml

let%html page =
  {|
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
      <link href="/assets/reset.css" rel="stylesheet">
      <link href="/assets/styles.css" rel="stylesheet">
      <title>Hello world!</title>
  </head>
  <body>
    <div class="container">
      <h1 class="hello">Hello world!</h1>
    </div>
  </body>
</html>
|}
;;
