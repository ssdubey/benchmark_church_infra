open Lwt.Infix

type distbuild = {artifact: string ; mutable metadata: (string * string) list ; count : int } 

module Distbuild = struct
  
  type t = distbuild
  
  let t = 
        let open Irmin.Type in 
        record "distbuild" (fun artifact metadata count ->
            {artifact; metadata; count; })
        |+ field "artifact" string (fun t -> t.artifact)
        |+ field "metadata" (list (pair string string)) (fun t -> t.metadata)
        |+ field "count" int (fun t -> t.count)
        |> sealr

    let uniq_cons x xs = if List.mem x xs then xs else x :: xs

    let remove_from_right xs = List.fold_right uniq_cons xs []

  let merge_build ~old x y =
    
    (* print_string "\nin merge_build"; *)
    
    let open Irmin.Merge.Infix in
    old () >>=* fun old ->
    let old = match old with None -> {artifact = "dummy"; metadata = [("IP", "TS")]; count = 0} | Some o -> o in 
    
    (*not considering the point where artifacts against the same key would be different due to version change, for eg.*)
    let metadata = x.metadata @ y.metadata in (*delete the duplicates from the list*)
    let metadata = remove_from_right metadata in

    (* Printf.printf "\nmetadata entries = %d \nxcount = %d, ycount = %d, oldcount= %d, final= %d" 
                                            (List.length metadata) x.count y.count old.count (x.count + y.count - old.count); *)

    let count = x.count + y.count - old.count in 
    Irmin.Merge.ok ({artifact = x.artifact; metadata = metadata; count = count})

    (* Irmin.Merge.ok ({artifact = "dummy"; metadata = [("IP", "TS")]; count = 0}) *)

  (* let merge = Irmin.Merge.(option (default t)) *)
  let merge = Irmin.Merge.(option (v t merge_build))

end


module Scylla_kvStore = Irmin_scylla.KV(Distbuild)

let rec printmeta valuemeta =
    match valuemeta with 
    | h::t -> let ip, ts = h in print_string ("\n IP= " ^ ip); print_string ("  TS= " ^ ts); printmeta t
    | _ -> ()

let printdetails msg key value = 
    print_string ("\n msg : " ^ msg);
    print_string ("  key : " ^ key);
    print_string ("  value: artifact : " ^ value.artifact ^ "\n metadata: ");
    printmeta value.metadata;
    print_string ("  count = "); print_int value.count; print_string "\n\n"

    
let readfile fileloc = 
    let buf = Buffer.create 4096 in
    try
        while true do
        let line = input_line fileloc in
        Buffer.add_string buf line;
        Buffer.add_char buf '\n'
        done;
        assert false 
    with
        End_of_file -> Buffer.contents buf

(* let getlib lib public_branch = 
    Scylla_kvStore.get public_branch [lib] >>= fun _ ->
    Lwt.return_unit *)

let find_in_db lib private_branch opr_time = 
    try 
    let stime = Unix.gettimeofday () in 
    Scylla_kvStore.get private_branch [lib] >>= fun _ ->
    let etime = Unix.gettimeofday () in
    (* Printf.printf "\nfind_in_db: %f" (etime -. stime); *)
    opr_time := !opr_time +. (etime -. stime);
    Lwt.return_true
    with 
    _ -> Lwt.return_false

let mergeBranches outBranch currentBranch opr_time = 
    let stime = Unix.gettimeofday () in (*Printf.printf "merging branch";*)
        ignore @@ Scylla_kvStore.merge_into ~info:(fun () -> Irmin.Info.empty) outBranch ~into:currentBranch;
    let etime = Unix.gettimeofday () in
    opr_time := !opr_time +. (etime -. stime);
    Lwt.return_unit

(* let rec mergeOpr branchList currentBranch repo =
    match branchList with 
    | h::t -> print_string ("\ncurrent branch to merge: " ^ h);Scylla_kvStore.of_branch repo h >>= fun branch ->    
                ignore @@ mergeBranches branch currentBranch;
                mergeOpr t currentBranch repo 
    | _ -> print_string "branch list empty"; Lwt.return_unit *)

let rec mergeOpr branchList currentBranch currentBranch_string repo opr_time = 
    match branchList with 
    | h::t -> 
            if (currentBranch_string <> h) then (  
                Scylla_kvStore.Branch.get repo h >>= fun other_head_cmt ->
                Scylla_kvStore.of_commit other_head_cmt >>= fun other_head ->
                
                    ignore @@ mergeBranches other_head currentBranch opr_time;
                    
                    mergeOpr t currentBranch currentBranch_string repo opr_time
                    )
                    else
                    mergeOpr t currentBranch currentBranch_string repo opr_time
    | _ -> Lwt.return_unit

let mergeOpr_help branchList currentBranch currentBranch_string repo opr_time =

    Scylla_kvStore.Branch.get repo currentBranch_string >>= fun current_head_cmt ->
    Scylla_kvStore.of_commit current_head_cmt >>= fun current_head ->
    
    ignore @@ mergeOpr branchList current_head currentBranch_string repo opr_time
    (* mergeOpr branchList currentBranch currentBranch_string repo opr_time *)
    ;mergeBranches current_head currentBranch opr_time

let filter_str str =
    let split = String.split_on_char '_' str in 
    let split = List.rev split in
    let status = List.hd split in
    if status="public" then true else false
    
let filter_public branchList =
    List.filter filter_str branchList

let create_or_get_public_branch repo ip = 
    try
    Scylla_kvStore.of_branch repo (ip ^ "_public")
    with _ -> 
    Scylla_kvStore.master repo >>= fun b_master ->
    Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_public")

let create_or_get_private_branch repo ip = 
    try
    Scylla_kvStore.of_branch repo (ip ^ "_private")
    with _ -> 
    Scylla_kvStore.master repo >>= fun b_master ->
    Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_private")
    
let refresh repo client opr_time =
    (*merge current branch with the detached head of other*) 
    create_or_get_public_branch repo client >>= fun public_branch_anchor ->
    Scylla_kvStore.Branch.list repo >>= fun branchList -> 
    
    let branchList = filter_public branchList in
            
    mergeOpr_help branchList public_branch_anchor (client ^ "_public") repo opr_time (*merge is returning unit*)
        
(*change getcontent to generate the value instead of taking it from file *)
(*let getcontent fileloc =
        let buf = Buffer.create 4096 in
try
        while true do
        let line = input_line fileloc in
        Buffer.add_string buf line;
        Buffer.add_char buf '\n'
        done;
        assert false
with
        End_of_file -> Buffer.contents buf
*)

let rand_chr () = (Char.chr (97 + (Random.int 26)));;

let rec getcontent len str = 
    if len > 0 then
        (let str = str ^ (String.make 1 (rand_chr ())) in
        getcontent (len -1) str)
    else
        str 

let createValue lib ip liblistpath =
    let ts = string_of_float (Unix.gettimeofday ()) in 
    
    (*let fileContentBuf = getcontent (open_in (liblistpath ^ lib ^ "_data")) in*)
    let contentBuf = getcontent 128 "" in
        (*let liblist = String.split_on_char('\n') fileContentBuf in
        List.tl (List.rev liblist)*)

    (*let libcontent = getcontent liblistpath in *)
    {artifact = contentBuf; metadata = [(ip, ts)]; count = 1}

let updateValue item ip =
let stime = Unix.gettimeofday() in
    let ts = string_of_float (Unix.gettimeofday ()) in
    let count = item.count + 1 in
    let metadata = (ip, ts) :: item.metadata in
    let etime = Unix.gettimeofday() in
let _ = etime -. stime in
(* Printf.printf "\nvalue_update: %f" diff; *)
    {artifact = item.artifact; metadata = metadata; count = count}


let rec build liblist private_branch_anchor cbranch_string repo ip liblistpath opr_time = (*cbranch_string as in current branch is only used for putting string in db*)
    match liblist with 
    | lib :: libls -> 
        find_in_db lib private_branch_anchor opr_time >>= fun boolval -> 
            (match boolval with 
            | false -> (let v = createValue lib ip liblistpath in
                        let stime = Unix.gettimeofday() in
                        
                        ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                private_branch_anchor [lib] v;
                        
                        let etime = Unix.gettimeofday() in
                        let diff = etime -. stime in
                        (* print_string "\ntime taken in inserting one key = ";  *)
(* Printf.printf "\nfalse_setting: %f" diff; *)
opr_time := !opr_time +. diff;
)
                        (*print_float (diff);*)

            | true ->             
                        let stime = Unix.gettimeofday() in
                        ignore (Scylla_kvStore.get private_branch_anchor [lib] >>= fun item ->
                        (* let item = Lwt_main.run (Scylla_kvStore.get private_branch_anchor [lib]) in  *)
                        (* let etime = Unix.gettimeofday() in
                        let diff1 = etime -. stime in *)
                        (* printdetails "old data" lib item; *)
                        let v = updateValue item ip in
                        (* let stime = Unix.gettimeofday() in *)
                        
                        ignore (Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                    private_branch_anchor [lib] v);
                        let etime = Unix.gettimeofday() in
                        let diff2 = etime -. stime in
                        (* Printf.printf "\ntrue_getting: %f" diff2;  *)
                        opr_time := !opr_time +. diff2;
                        Lwt.return_unit)
                        );
(* (diff1 +. diff2)) in *)
(* Printf.printf"\n%f" elapse; *)

(* ignore (create_or_get_public_branch repo ip >>= fun public_branch_anchor ->
            Scylla_kvStore.get public_branch_anchor [lib] >>= fun item ->
                        printdetails "new data" lib item;
                        Lwt.return_unit);                                      *)

        build libls private_branch_anchor cbranch_string repo ip liblistpath opr_time;

    | [] -> Lwt.return_unit

let file_to_liblist liblistpath = 
    let fileContentBuf = readfile (open_in liblistpath) in 
    let liblist = String.split_on_char('\n') fileContentBuf in
    List.tl (List.rev liblist)


let testfun public_branch_anchor lib msg =
    Scylla_kvStore.get public_branch_anchor [lib] >>= fun item ->
                        printdetails msg lib item;
    Lwt.return_unit

let publish branch1 branch2 opr_time = (*changes of branch2 will merge into branch1*)
    (* Irmin_scylla.gc_meta_fun branch2; branch2 is a string and the branch which is sending its changes. make sure this is alwyas private. *)
    let stime = Unix.gettimeofday() in
        ignore @@ Scylla_kvStore.merge_with_branch ~info:(fun () -> Irmin.Info.empty) branch1 branch2;
    let etime = Unix.gettimeofday() in
    let diff = etime -. stime in
    opr_time := !opr_time +. diff

(*publishing the changes*)
let publish_to_public repo ip opr_time =
    create_or_get_public_branch repo ip >>= fun public_branch_anchor ->
    (*changes of 2nd arg branch will merge into first*)
    ignore @@ publish public_branch_anchor (ip ^ "_private") opr_time;
    Lwt.return_unit 

(* let rec resolve_lwt lst = *)
    

let squash repo private_branch_str public_branch_str = 
    Scylla_kvStore.Branch.get repo private_branch_str >>= fun latest_cmt ->
    let latest_tree = Scylla_kvStore.Commit.tree latest_cmt in

    Scylla_kvStore.Branch.get repo public_branch_str >>= fun old_commit ->
    Scylla_kvStore.Commit.v repo ~info:(Irmin.Info.empty) ~parents:[Scylla_kvStore.Commit.hash old_commit] latest_tree >>= fun new_commit -> 
    (* print "%s" (Irmin.Type.to_string (Scylla_kvStore.Commit.t repo) new_commit); *)

    Scylla_kvStore.of_branch repo private_branch_str >>= fun private_branch_anchor ->
    Scylla_kvStore.Head.set private_branch_anchor new_commit

    (* Lwt.return_unit *)

(*The design of this system is such that each client will update the libraries in its private branch then publish it and call refresh. Refresh only 
updates the public branch. Since I am taking input in such a way that there is 80% read and 20% write for each private branch, refresh over the 
private branch doesn't seem necessary for benchmark purpose*)

let buildLibrary ip client liblistpath libindex opr_time ref_time publish_time =
    let conf = Irmin_scylla.config ip in
    Scylla_kvStore.Repo.v conf >>= fun repo ->
    (* ignore liblistpath;*)
    create_or_get_private_branch repo client >>= fun private_branch_anchor ->
    
    let liblist = file_to_liblist (liblistpath ^ libindex)in
    
    ignore @@ build liblist private_branch_anchor (client ^ "_private") repo client liblistpath opr_time;

    ignore @@ publish_to_public repo client publish_time;

    ignore @@ refresh repo client ref_time;
    (*ignore @@ squash repo (client ^ "_private") (client ^ "_public");*)

    Lwt.return_unit 


let _ =
        let hostip = Sys.argv.(1) in
        let client = Sys.argv.(2) in
        let libpath = Sys.argv.(3) in
        let libindex = Sys.argv.(4) in 

        Random.init (Unix.getpid ());

        (*let ip = "127.0.0.1" in
        let liblistpath = "/home/shashank/work/benchmark_irminscylla/build_system/input/buildsystem/" in
        Buildsystem.buildLibrary ip liblistpath*)
        let opr_time = ref 0.0 in 
        let ref_time = ref 0.0 in 
        let publish_time = ref 0.0 in
        ignore @@ buildLibrary hostip client libpath libindex opr_time ref_time publish_time;

        Printf.printf "\n%f;%f;%f" !opr_time !publish_time !ref_time

        
    (*In this code private branch takes up all the updates and then push everything to the public brnach. All the functioning at public branch
    like refresh is commented. *)


(* Squash extra: *)
    (* let parent_hash_list = Scylla_kvStore.Commit.parents old_commit in  *)
    (* let parent_commit_option_list = List.map (fun x -> Lwt_main.run (Scylla_kvStore.Commit.of_hash repo x)) parent_hash_list in
    let parent_commit_list = List.map (fun x -> match x with | Some y -> y | None -> failwith "bad commit") parent_commit_option_list in 
    let hash_parent_list = List.map (fun x -> Scylla_kvStore.Commit.hash x) parent_commit_list in  *)

    (* Scylla_kvStore.Commit.v repo ~info:(Irmin.Info.empty) ~parents:parent_hash_list latest_tree >>= fun new_commit ->  *)
    
