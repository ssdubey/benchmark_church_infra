open Lwt.Infix

module Counter: Irmin.Contents.S with type t = int64 = struct
	type t = int64
	let t = Irmin.Type.int64
	let mc = ref 0
    let merge ~old a b = 
    let open Irmin.Merge.Infix in
		old () >|=* fun old ->
        let old = match old with None -> 0L | Some o -> o in
        let (+) = Int64.add and (-) = Int64.sub in 
        a + b - old
        
        let merge = Irmin.Merge.(option (v t merge))
end

module Scylla_kvStore = Irmin_scylla.KV(Counter)

let updateMeta meta_name msg time = 
    let _, time_sum, cnt = !meta_name in
    let count = cnt + 1 in  
    let t = time_sum +. time in
    meta_name := (msg, t, count)

let mergeBranches outBranch currentBranch opr_meta = 
    let stime = Unix.gettimeofday () in 
        ignore @@ Scylla_kvStore.merge_into ~info:(fun () -> Irmin.Info.empty) outBranch ~into:currentBranch;
    let etime = Unix.gettimeofday () in
      updateMeta opr_meta "mergebranches" (etime -. stime);

        Lwt.return_unit

let rec mergeOpr branchList currentBranch currentBranch_string repo opr_meta = 
    match branchList with 
    | h::t -> 
            if (currentBranch_string <> h) then (  
                Scylla_kvStore.Branch.get repo h >>= fun other_head_cmt ->
                Scylla_kvStore.of_commit other_head_cmt >>= fun other_head ->
                
                    ignore @@ mergeBranches other_head currentBranch opr_meta;
                    
                    mergeOpr t currentBranch currentBranch_string repo opr_meta
                    )
                    else
                    mergeOpr t currentBranch currentBranch_string repo opr_meta
    | _ -> Lwt.return_unit
        
let mergeOpr_help branchList currentBranch currentBranch_string repo opr_meta =

  Scylla_kvStore.Branch.get repo currentBranch_string >>= fun current_head_cmt ->
  Scylla_kvStore.of_commit current_head_cmt >>= fun current_head ->

  ignore @@ mergeOpr branchList current_head currentBranch_string repo opr_meta
  ;mergeBranches current_head currentBranch opr_meta

let createValue () =
    Int64.of_int (Random.int 10)

let getvalue private_branch_anchor lib client get_meta =
    let stime = Unix.gettimeofday() in
        Scylla_kvStore.get private_branch_anchor [lib] >>= fun item -> 
        ignore item;
    let etime = Unix.gettimeofday() in
    updateMeta get_meta "getvalue" (etime -. stime);
    
    Lwt.return_unit

let rec build liblist private_branch_anchor repo client set_meta get_meta rw = (*cbranch_string as in current branch is only used for putting string in db*)
    match liblist with 
    | lib :: libls -> 
             
        (match rw with 
            | "post_write" -> ( 
                        let v = createValue () in
                        let stime = Unix.gettimeofday() in
                        
                        ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                private_branch_anchor [lib] v;
                        
                        let etime = Unix.gettimeofday() in
                        let diff = etime -. stime in
                        updateMeta set_meta "build_write" diff;
                         
                        )

            | "read" -> 
                ignore @@ getvalue private_branch_anchor lib client get_meta
            
            | _ -> failwith "wrong option for rw");

        build libls private_branch_anchor repo client set_meta get_meta rw;

    | [] -> Lwt.return_unit


(*generating key of 2B *)
let gen_write_key () = 
  let str = [|"1";"2";"3";"4";"5";"6";"7";"8";"9";"0";"a";"b";"c";"d";"e";"f";"g";"h";"i";"j";"k";"l";"m";"n";"o";"p";"q";"r";"s";"t";"u";"v";|] in
  let key = (Array.get str (Random.int 32))^(Array.get str (Random.int 32)) in
  key


(*generating 2B random key from limited keyspace*)
let rec generate_write_key_list count = 
  if (count>0) then (
      gen_write_key () :: generate_write_key_list (count -1) )
  else
      []
  
let create_or_get_private_branch repo ip = 
  try
  Scylla_kvStore.of_branch repo (ip ^ "_private") (*this should never fail*)
  with _ -> 
  Printf.printf "\nget private branch failed which is an error...";
  Scylla_kvStore.master repo >>= fun b_master ->
  Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_private")

let create_or_get_public_branch repo ip = 
  try
  Scylla_kvStore.of_branch repo (ip ^ "_public")
  with _ -> 
  Scylla_kvStore.master repo >>= fun b_master ->
  Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_public")

let publish branch1 branch2 publish_meta client = (*changes of branch2 will merge into branch1*)
    let stime = Unix.gettimeofday() in
        ignore @@ Scylla_kvStore.merge_with_branch ~info:(fun () -> Irmin.Info.empty) branch1 branch2;
    let etime = Unix.gettimeofday() in
    let diff = etime -. stime in
    updateMeta publish_meta "publish_merge" diff

let publish_to_public repo ip publish_meta = 
    create_or_get_public_branch repo ip >>= fun public_branch_anchor ->
    (*changes of 2nd arg branch will merge into first*)
    ignore @@ publish public_branch_anchor (ip ^ "_private") publish_meta ip;
    Lwt.return_unit 


let filter_str str =
  let split = String.split_on_char '_' str in 
  let split = List.rev split in
  let status = List.hd split in
  if status="public" then true else false

let filter_public branchList =
  List.filter filter_str branchList


let refresh repo client refresh_meta =
  (*merge current branch with the detached head of other*) 
  create_or_get_public_branch repo client >>= fun public_branch_anchor ->
  Scylla_kvStore.Branch.list repo >>= fun branchList -> 
  
  let branchList = filter_public branchList in
        
  mergeOpr_help branchList public_branch_anchor (client ^ "_public") repo refresh_meta  (*merge is returning unit*)
  
let post_operate_help opr_load private_branch_anchor repo client total_opr_load flag set_meta get_meta publish_meta refresh_meta =
  let write_keylist = generate_write_key_list opr_load in (*generate_write_key_list is generating key for write operation*)
  ignore @@ build write_keylist private_branch_anchor repo client set_meta get_meta "post_write";

  ignore @@ build write_keylist private_branch_anchor repo client set_meta get_meta "read";
  ignore @@ (create_or_get_public_branch repo client >>= fun public_branch_anchor ->
  ignore @@ publish_to_public repo client publish_meta;
  
  ignore @@ build write_keylist public_branch_anchor repo client set_meta get_meta "read";

  ignore @@ refresh repo client refresh_meta;
  
  Lwt.return_unit)
  

let rec operate opr_load private_branch_anchor repo client total_opr_load flag done_opr set_meta get_meta publish_meta refresh_meta =
  let rw_load = opr_load/2 in
  
  post_operate_help rw_load private_branch_anchor repo client total_opr_load flag set_meta get_meta publish_meta refresh_meta;
      
  (*this will make the keys generated in 2^x groups*)
  let new_opr_load, flag = 
  if (done_opr + (2 * opr_load)) < total_opr_load then
      ((2 * opr_load), true)
  else    
      ((total_opr_load - done_opr), false)
  in
  
  let done_opr = done_opr + new_opr_load in

  if flag=true then (*flag denotes if it is a last round of operation or not. true = more rounds are there, false = no more rounds*)
      operate new_opr_load private_branch_anchor repo client total_opr_load flag done_opr set_meta get_meta publish_meta refresh_meta
  else  if new_opr_load != 0 then(
      let rw_load = new_opr_load/2 in
      
      post_operate_help rw_load private_branch_anchor repo client total_opr_load flag set_meta get_meta publish_meta refresh_meta
  
  )  
    

let buildLibrary ip client total_opr_load set_meta get_meta publish_meta refresh_meta =
  let conf = Irmin_scylla.config ip in
  Scylla_kvStore.Repo.v conf >>= fun repo ->
  
  create_or_get_private_branch repo client >>= fun private_branch_anchor ->
  
  let opr_load = 2 in 
  let done_opr = 2 in
  operate opr_load private_branch_anchor repo client total_opr_load true done_opr set_meta get_meta publish_meta refresh_meta;
  (* ignore @@ refresh repo client refresh_meta; *)
  Lwt.return_unit 

let _ =
  let hostip = Sys.argv.(1) in
  let client = Sys.argv.(2) in
  let total_opr_load = Sys.argv.(3) in (* no. of keys to insert *)
  Random.init (Unix.getpid ());

  let set_meta = ref ("", 0.0, 0) in 
  let get_meta = ref ("", 0.0, 0) in 
  let publish_meta = ref ("", 0.0, 0) in 
  let refresh_meta = ref ("", 0.0, 0) in 

  
  ignore @@ buildLibrary hostip client (int_of_string total_opr_load) set_meta get_meta publish_meta refresh_meta;

  let (set_msg, set_time, set_count) = !set_meta in 
  let (get_msg, get_time, get_count) = !get_meta in 
  let (publish_msg, publish_time, publish_count) = !publish_meta in 
  let (refresh_msg, refresh_time, refresh_count) = !refresh_meta in 
  
  let total_time = set_time +. get_time +. publish_time +. refresh_time in 
  (* Printf.printf "\n\nset_time = %f;set_count = %d;get_time = %f;get_count = %d;publish_time = %f;publish_count = %d;refresh_time = %f;refresh_count = %d;total_time = %f" set_time set_count get_time get_count publish_time publish_count refresh_time refresh_count total_time; *)

  Printf.printf "\n%f; %d; %f; %d; %f; %d; %f; %d; %f" set_time set_count get_time get_count publish_time publish_count refresh_time refresh_count total_time;
  