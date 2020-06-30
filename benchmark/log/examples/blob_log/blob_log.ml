(*---------------------------------------------------------------------------
   Copyright (c) 2016 KC Sivaramakrishnan. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

open Lwt.Infix

let return = Lwt.return

module String = struct
	type t = string
	let t = Irmin.Type.string
end

module M = Irmin_containers.Blob_log.Quick(String)
open M

let rec append_msgs m = function
  | [] -> Lwt.return ()
  | x::xs ->
      append m ~path:["head"] x >>= fun () ->
      append_msgs m xs

let test_append_read () =
  Printf.printf "\n(** append and read **)\n";
  init ~root:"/tmp/ezirmin" ~bare:false >>= master >>= fun m ->
  append_msgs m ["master.1"; "master.2"] >>= fun () ->
  read_all m ~path:["head"] >>= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l;
  Printf.printf "\n(** appending more **)\n";
  append_msgs m ["master.3"; "master.4"] >>= fun () ->
  read_all m ~path:["head"] >>= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l

let test_branch_append_read () =
  Printf.printf "\n(** branch, append and read **)\n";
  init ~root:"/tmp/ezirmin" ~bare:false >>= master >>= fun m ->
  clone ~src:m ~dst:"working" >>= fun w ->
  append_msgs w ["working.1"; "working.2"] >>= fun () ->
  append_msgs m ["master.5"; "master.6"] >>= fun () ->
  merge_into w ~into:m >>= fun () ->
  append_msgs m ["master.7"; "master.8"] >>= fun () ->
  read_all m ~path:["head"] >>= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l

let test_get_branch () =
  Printf.printf "\n(** get branch **)\n";
  init ~root:"/tmp/ezirmin" ~bare:false >>= fun r ->
  of_branch r "foobar" >>= fun fb ->
  append_msgs fb ["foobar.1"; "foobar.2"] >>= fun () ->
  read_all fb ~path:["head"] >|= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l


let _ = Lwt_main.run (
  test_append_read () >>=
  test_branch_append_read >>=
  test_get_branch
)

(*---------------------------------------------------------------------------
   Copyright (c) 2016 KC Sivaramakrishnan

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
