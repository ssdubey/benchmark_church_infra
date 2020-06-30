(*---------------------------------------------------------------------------
   Copyright (c) 2016 KC Sivaramakrishnan. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

open Lwt.Infix

module String_ = struct
	type t = string
	let t = Irmin.Type.string
end

module M = Irmin_containers.Log.Quick(String_)
open M

let rec append_msgs m = function
  | [] -> Lwt.return ()
  | x::xs ->
      append m ~path:["head"] x >>= fun () ->
      append_msgs m xs

let read_all_incrementally m =
  let rec loop cursor =
    read cursor ~num_items:2 >>= fun (l, cursor) ->
    List.iter (fun s -> Printf.printf "%s\n" s) l;
    match cursor with
    | None -> Printf.printf "<read_done>\n"; Lwt.return ()
    | Some cursor -> Printf.printf "<read_more>..\n"; loop cursor
  in
  get_cursor m ~path:["head"] >>= function
  | None -> failwith "test_append_read_cursor : impossible"
  | Some c -> loop c

let test_append_read_all repo_lwt =
  Printf.printf "\n(** append and read all **)\n";
  repo_lwt >>= master >>= fun m ->
  append_msgs m ["master.1"; "master.2"] >>= fun () ->
  read_all m ~path:["head"] >|= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l

let test_append_read_incr repo_lwt =
  Printf.printf "\n(** append and read incrementally **)\n";
  repo_lwt >>= master >>= fun m ->
  append_msgs m ["master.3"; "master.4"] >>= fun () ->
  read_all_incrementally m

let test_branch_append_read_incr repo_lwt =
  Printf.printf "\n(** branch, append and read incrementally **)\n";
  repo_lwt >>= master >>= fun m ->
  clone ~src:m ~dst:"working" >>= fun w ->
  append_msgs w ["working.1"; "working.2"] >>= fun () ->
  append_msgs m ["master.5"; "master.6"] >>= fun () ->
  merge_into w ~into:m >>= fun () ->
  append_msgs m ["master.7"; "master.8"] >>= fun () ->
  read_all_incrementally m

let test_get_branch repo_lwt =
  Printf.printf "\n(** get branch **)\n";
  repo_lwt >>= fun r ->
  of_branch r "foobar" >>= fun fb ->
  append_msgs fb ["foobar.1"; "foobar.2"] >>= fun () ->
  read_all fb ~path:["head"] >|= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l


let append_log client_branch log_list =
  Printf.printf "\n(** append and read all **)\n";
  append_msgs client_branch log_list >>= fun () -> Lwt.return_unit
  (* read_all client_branch ~path:["head"] >|= fun l ->
  List.iter (fun s -> Printf.printf "%s\n" s) l *)

let rand_chr () = (Char.chr (97 + (Random.int 26)));;

let rec getcontent len str = 
    if len > 0 then
        (let str = str ^ (String.make 1 (rand_chr ())) in
        getcontent (len -1) str)
    else
        str 

let rec generate_log_list log_size log_count loglist =
  if log_count > 0 then(
    let loglist = (getcontent log_size "") :: loglist in
    generate_log_list log_size (log_count - 1) loglist
  )else(
    loglist
  )

let refresh repo replica =
  create_or_get_public_branch repo replica >>= fun public_branch_anchor ->
  Scylla_kvStore.Branch.list repo >>= fun branchList -> 
  
  let branchList = filter_public branchList in
        
  mergeOpr_help branchList public_branch_anchor (replica ^ "_public") repo refresh_meta  (*merge is returning unit*)
  

let rec operate repo client_branch replica total_log_count done_appends = 
  (*argument is no. of characters in single log and list size for a single ammend opr*)
  let batch_count = 5 in
  let loglist = if total_log_count > batch_count then (
    generate_log_list 128 batch_count [] 
  )
  else (
    generate_log_list 128 total_log_count []
  ) in
  
  ignore @@ append_log client_branch loglist;

  refresh repo replica

  if done_appends = false then (
    if (total_log_count - batch_count > batch_count) then (
      operate client_branch (total_log_count - batch_count) false
    )
    else (
      operate client_branch total_log_count true
    )
  )

(**genrate log with random chars and append with the single head*)
let create_insert_log hostip client total_log_count replica = 
  Lwt_main.run (
  init ~root:hostip ~bare:false >>= fun repo -> master repo >>= fun master_branch ->
    clone ~src:master_branch ~dst:client >>= fun client_branch ->

    operate repo client_branch replica total_log_count false;
    Lwt.return_unit
  

  (* test_append_read_all repo_lwt >>= fun () ->
  test_append_read_incr repo_lwt >>= fun () -> 
  test_branch_append_read_incr repo_lwt >>= fun () -> print_string "printing foobar " ;
  test_get_branch repo_lwt *)
)

let _ =
  let hostip = Sys.argv.(1) in
  let client = Sys.argv.(2) in
  let total_log_count = Sys.argv.(3) in (* no. of keys to insert *)
  let replica = Sys.argv.(4) in 
  Random.init (Unix.getpid ());
ignore total_log_count; ignore replica;

  create_insert_log hostip client (int_of_string total_log_count) replica
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
