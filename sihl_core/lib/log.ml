open Base

let stamp_tag : string Logs.Tag.def =
  Logs.Tag.def "stamp" ~doc:"Relative monotonic time stamp" String.pp

let stamp c = Logs.Tag.(empty |> add stamp_tag c)

(* let reporter ppf =
 *   let report _ level ~over k msgf =
 *     let k _ =
 *       over ();
 *       k ()
 *     in
 *     let with_stamp h tags k ppf fmt =
 *       let stamp =
 *         match tags with
 *         | None -> None
 *         | Some tags -> Logs.Tag.find stamp_tag tags
 *       in
 *       let txt = match stamp with None -> "" | Some txt -> txt in
 *       Format.kfprintf k ppf fmt Logs.pp_header (level, h) txt
 *     in
 *     msgf @@ fun ?header ?tags fmt -> with_stamp header tags k ppf fmt
 *   in
 *   { Logs.report }
 * 
 * let main () =
 *   Logs.set_reporter (reporter Format.std_formatter);
 *   Logs.set_level (Some Logs.Info);
 *   run ();
 *   run ();
 *   () *)
