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

let updateMeta meta_name msg time = 
  let _, time_sum, cnt = !meta_name in
  let count = cnt + 1 in  
  let t = time_sum +. time in
  meta_name := (msg, t, count)

let append_log client_branch log_list opr_meta =
  let stime = Unix.gettimeofday () in 
    append_msgs client_branch log_list >>= fun () -> 
  let etime = Unix.gettimeofday () in
    updateMeta opr_meta "append_log" (etime -. stime);
    Lwt.return_unit
(*
  Printf.printf "\n(** append and read all **)\n";
  *)

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

let filter_str str =
  let split = String.split_on_char '_' str in 
  let split = List.rev split in
  let status = List.hd split in
  if status="public" then true else false

let filter_public branchList =
  List.filter filter_str branchList

let create_or_get_private_branch repo branch_string = 
  try
  of_branch repo (branch_string ^ "_private") (*this should never fail*)
  with _ -> 
  Printf.printf "\nget private branch failed which is an error...";
  master repo >>= fun b_master ->
  clone ~src:b_master ~dst:(branch_string ^ "_private")

let create_or_get_public_branch repo branch_string = 
  try
  of_branch repo (branch_string ^ "_public")
  with _ -> 
  master repo >>= fun b_master ->
  clone ~src:b_master ~dst:(branch_string ^ "_public")
  
let mergeBranches outBranch currentBranch opr_meta = 
  let stime = Unix.gettimeofday () in 
      ignore @@ merge_into outBranch ~into:currentBranch;
  let etime = Unix.gettimeofday () in
    updateMeta opr_meta "mergebranches" (etime -. stime);

      Lwt.return_unit

let rec mergeOpr branchList currentBranch currentBranch_string repo opr_meta = 
  match branchList with 
  | h::t -> 
          if (currentBranch_string <> h) then (  
            (* Printf.printf "\n** merge of %s into %s" h currentBranch_string; *)
              (* get_head repo h >>= fun other_head_cmt ->
              of_commit other_head_cmt >>= fun other_head -> *)
              
               of_branch repo h >>= fun other_head ->
                  ignore @@ mergeBranches other_head currentBranch opr_meta;
                  
                  mergeOpr t currentBranch currentBranch_string repo opr_meta
                  )
                  else
                  mergeOpr t currentBranch currentBranch_string repo opr_meta
  | _ -> Lwt.return_unit
    
let refresh repo replica refresh_meta =
  create_or_get_public_branch repo replica >>= fun public_branch_anchor ->
  (* Branch.list repo >>= fun branchList ->  *)
  
  (* let branchList = filter_public branchList in *)
  let branchlist = ["1_public";"2_public"] in
  mergeOpr branchlist public_branch_anchor (replica ^ "_public") repo refresh_meta
  

let rec operate repo client_branch replica total_log_count done_appends set_meta get_meta publish_meta refresh_meta = 
  (*argument is no. of characters in single log and list size for a single ammend opr*)
  let batch_count = 5 in
  let loglist = if total_log_count > batch_count then (
    generate_log_list 128 batch_count [] 
  )
  else (
    generate_log_list 128 total_log_count []
  ) in
  
  ignore @@ append_log client_branch loglist set_meta;

  ignore @@ refresh repo replica refresh_meta;

  if done_appends = false then (
    if (total_log_count - batch_count > batch_count) then (
      operate repo client_branch replica (total_log_count - batch_count) false set_meta get_meta publish_meta refresh_meta
    )
    else (
      operate repo client_branch replica total_log_count true set_meta get_meta publish_meta refresh_meta
    )
  )

  let publish branch1 branch2 publish_meta = (*changes of branch2 will merge into branch1*)
  print_string "publishing...";
  let stime = Unix.gettimeofday() in
      (* ignore @@ merge_with_branch ~info:(fun () -> Irmin.Info.empty) branch1 branch2; *)
      ignore @@ merge_into ~into:branch1 branch2;
  let etime = Unix.gettimeofday() in
  let diff = etime -. stime in
  updateMeta publish_meta "publish_merge" diff

let publish_to_public repo ip replica publish_meta = 
  create_or_get_public_branch repo replica >>= fun public_branch_anchor ->
  create_or_get_private_branch repo ip >>= fun private_branch_anchor ->
  (*changes of 2nd arg branch will merge into first*)
  (* ignore @@ publish public_branch_anchor (ip ^ "_private") publish_meta ip; *)
  ignore @@ publish public_branch_anchor private_branch_anchor publish_meta;
  Lwt.return_unit 


(**genrate log with random chars and append with the single head*)
let create_insert_log hostip client total_log_count replica set_meta get_meta publish_meta refresh_meta = 
  Lwt_main.run (
  init ~root:hostip ~bare:false >>= fun repo -> 
  (* master repo >>= fun master_branch -> *)
  create_or_get_private_branch repo client >>= fun client_branch ->
    (* clone ~src:master_branch ~dst:client >>= fun client_branch -> *)

    operate repo client_branch replica total_log_count false set_meta get_meta publish_meta refresh_meta;

    ignore @@ publish_to_public repo client replica publish_meta ;
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

let set_meta = ref ("", 0.0, 0) in 
  let get_meta = ref ("", 0.0, 0) in 
  let publish_meta = ref ("", 0.0, 0) in 
  let refresh_meta = ref ("", 0.0, 0) in 


  create_insert_log hostip client (int_of_string total_log_count) replica set_meta get_meta publish_meta refresh_meta;

  let (set_msg, set_time, set_count) = !set_meta in 
  let (get_msg, get_time, get_count) = !get_meta in 
  let (publish_msg, publish_time, publish_count) = !publish_meta in 
  let (refresh_msg, refresh_time, refresh_count) = !refresh_meta in 
  
  let total_time = set_time +. get_time +. publish_time +. refresh_time in 
  (* Printf.printf "\n\nset_time = %f;set_count = %d;get_time = %f;get_count = %d;publish_time = %f;publish_count = %d;refresh_time = %f;refresh_count = %d;total_time = %f" set_time set_count get_time get_count publish_time publish_count refresh_time refresh_count total_time; *)
ignore (set_msg^get_msg^publish_msg^refresh_msg);
  Printf.printf "\n%f; %d; %f; %d; %f; %d; %f; %d; %f" set_time set_count get_time get_count publish_time publish_count refresh_time refresh_count total_time;
  
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
