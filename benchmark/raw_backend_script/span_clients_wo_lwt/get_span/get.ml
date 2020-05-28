open Lwt.Infix

module Scylla_kvStore = Irmin_scylla.KV(Irmin.Contents.String)

let readfile fileloc = 
let buf = Buffer.create 4096 in
try
    while true do
      let line = input_line fileloc in
      Buffer.add_string buf line;
      Buffer.add_char buf '\n';
    done;
    assert false 
  with
    End_of_file -> Buffer.contents buf

let getkeylist path = 
  let contentbuf = readfile (open_in path) in 
  let keylist = String.split_on_char('\n') contentbuf in
  let keylist = List.map (String.split_on_char('-')) keylist in  
  (* let keylist = List.tl (List.rev keylist) in   *)
  keylist

let rec getvalue keylist b_master =
	match keylist with 
    | h::t -> (try 
            (*print_string h;*)
            Scylla_kvStore.get b_master h 
				 >>= fun _ ->
			  	(*print_string item ;*) 
                                 getvalue t b_master 
			  with 
			  _ ->  getvalue t b_master); 
              
    | _ -> Lwt.return_unit

 

let _ =
        let hosts = Sys.argv.(1) in
        let path = Sys.argv.(2) in

        (*let path = "/home/shashank/work/benchmark/input/heirarchical_keys/1l1k/keys" in*)
(*let conf = Irmin_scylla.config "172.17.0.2" in*)
let conf = Irmin_scylla.config hosts in 
Scylla_kvStore.Repo.v conf >>= fun repo ->
	Scylla_kvStore.master repo >>= fun b_master ->
		(* Scylla_kvStore.get b_master ["ztkmIyHy6x"; "XoEH0L7oEO"] >>= fun item -> *)
                print_string "1";
		let keylist = getkeylist path in 

                let stime = Unix.gettimeofday() in
		  ignore @@ getvalue keylist b_master;
                let etime = Unix.gettimeofday() in
                let diff = etime -. stime in

                print_string "\ntotal time taken = ";
                print_float diff;
                print_string "\n\n\n";
		Lwt.return_unit
