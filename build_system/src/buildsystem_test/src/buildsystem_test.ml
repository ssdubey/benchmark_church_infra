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

  let merge_build ~old x y =
  ignore old;
  ignore x;
  ignore y;
     print_string "\nin merge_build";
    (*
    let open Irmin.Merge.Infix in
    old () >>=* fun old ->
    let old = match old with None -> {artifact = "dummy"; metadata = [("IP", "TS")]; count = 0} | Some o -> o in 
    
    (*not considering the point where artifacts against the same key would be different due to version change, for eg.*)
    let metadata = x.metadata @ y.metadata in
    Printf.printf "\nmetadata entries = %d \nxcount = %d, ycount = %d, oldcount= %d, final= %d" 
                                            (List.length metadata) x.count y.count old.count (x.count + y.count + old.count);
    let count = x.count + y.count + old.count in 
    Irmin.Merge.ok ({artifact = x.artifact; metadata = metadata; count = count}) *)

    Irmin.Merge.ok ({artifact = "dummy"; metadata = [("IP", "TS")]; count = 0})

  let merge = print_string "\nmergefun\n"; Irmin.Merge.(option (v t merge_build))

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
    print_string ("  count = "); print_int value.count

let build_1 = {artifact = "artifact1"; metadata = [("IP1", "TS1")]; count = 1}
let build_2 = {artifact = "artifact2"; metadata = [("IP1", "TS2")]; count = 1}
let build_3 = {artifact = "artifact3"; metadata = [("IP1", "TS3")]; count = 1}
let build_4 = {artifact = "artifact1"; metadata = [("IP2", "TS4")]; count = 1}
let build_5 = {artifact = "artifact2"; metadata = [("IP2", "TS5")]; count = 1}
let build_6 = {artifact = "artifact3"; metadata = [("IP2", "TS6")]; count = 1}

let testcase1 () = 
    let ip = "172.17.0.4" in
    let conf = Irmin_scylla.config ip in
    Scylla_kvStore.Repo.v conf >>= fun repo ->
    Scylla_kvStore.master repo >>= fun b_master ->  
    Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_public") >>= fun public_branch_anchor ->  


    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                b_master ["key1"] build_1;

    Scylla_kvStore.get b_master ["key1"] >>= fun item ->
    printdetails "after inserting key1 at client1" "key1" item;

    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                b_master ["key2"] build_2;

    Scylla_kvStore.get b_master ["key2"] >>= fun item ->
    printdetails "after inserting key2 at client1" "key2" item;

    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                b_master ["key3"] build_3;

    Scylla_kvStore.get b_master ["key3"] >>= fun item ->
    printdetails "after inserting key3 at client1" "key3" item;


    

    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                public_branch_anchor ["key1"] build_4;

    Scylla_kvStore.get public_branch_anchor ["key1"] >>= fun item ->
    printdetails "after inserting key1 at client2" "key1" item;

    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                public_branch_anchor ["key2"] build_5;

    Scylla_kvStore.get public_branch_anchor ["key2"] >>= fun item ->
    printdetails "after inserting key2 at client2" "key2" item;
    
    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                public_branch_anchor ["key3"] build_6;

    Scylla_kvStore.get public_branch_anchor ["key3"] >>= fun item ->
    printdetails "after inserting key3 at client2" "key3" item;
    


    ignore @@ Scylla_kvStore.merge_into ~info:(fun () -> Irmin.Info.empty) public_branch_anchor ~into:b_master; (*~into is always the second argument in the merge function*)

    Scylla_kvStore.get b_master ["key1"] >>= fun item ->
    printdetails "after merging two branches key1 at client1" "key1" item;
    
    Lwt.return_unit

let testcase2 () = 
    let ip = "172.17.0.4" in
    let conf = Irmin_scylla.config ip in
    Scylla_kvStore.Repo.v conf >>= fun repo ->
    Scylla_kvStore.master repo >>= fun b_master ->  
    Scylla_kvStore.clone ~src:b_master ~dst:(ip ^ "_public") >>= fun public_branch_anchor ->  
    (* Scylla_kvStore.of_branch repo (ip ^ "_public") >>= fun public_branch_anchor -> *)

    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                b_master ["key1"] build_1;

    Scylla_kvStore.get b_master ["key1"] >>= fun item ->
    printdetails "after inserting key1 at client1" "key1" item;


    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                public_branch_anchor ["key1"] build_4;

    Scylla_kvStore.get public_branch_anchor ["key1"] >>= fun item ->
    printdetails "after inserting key1 at client2" "key1" item;


    ignore @@ Scylla_kvStore.set_exn ~info:(fun () -> Irmin.Info.empty) 
                                                b_master ["key1"] build_1;

    Scylla_kvStore.get b_master ["key1"] >>= fun item ->
    printdetails "after inserting key1 at client1" "key1" item;


    ignore @@ Scylla_kvStore.merge_into ~info:(fun () -> Irmin.Info.empty) public_branch_anchor ~into:b_master;
    
    Scylla_kvStore.get b_master ["key1"] >>= fun item ->
    printdetails "after merging two branches key1 at client1" "key1" item;

    Lwt.return_unit

let main () =
    (* testcase1 (); *)
    testcase2 ()
    