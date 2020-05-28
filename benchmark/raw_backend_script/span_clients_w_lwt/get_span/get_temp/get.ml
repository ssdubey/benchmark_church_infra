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
  let keylist = List.map (fun x -> String.split_on_char '-' x) keylist in
  let keylist = List.tl (List.rev keylist) in 
  keylist

let rec getvalue keylist b_master =
	match keylist with 
    | h::t -> (try 
            ignore @@ Scylla_kvStore.get b_master h;
            getvalue t b_master 
	  with 
          _ -> Printf.printf "\nexception in get";
               getvalue t b_master);

    | _ -> Lwt.return_unit

 (*let rec getvalue keylist b_master =
	match keylist with 
    | h::t -> 
    (try 
            ignore h; Scylla_kvStore.get b_master h >>= fun item ->
			  	print_string ("\n"^item) ; 
          getvalue t b_master 
			  with 
                          _ -> Printf.printf "\nexception in get";
                          getvalue t b_master);
              
    | _ -> Lwt.return_unit
*)

let _ =
(*let path = "/home/shashank/work/benchmark_irminscylla/input/heirarchical_keys/1l1k/keys" in
let conf = Irmin_scylla.config "127.0.0.1" in*)
let hosts = Sys.argv.(1) in
let path = Sys.argv.(2) in

let conf = Irmin_scylla.config hosts in 
Scylla_kvStore.Repo.v conf >>= fun repo ->
	Scylla_kvStore.master repo >>= fun b_master ->
		(* Scylla_kvStore.get b_master ["foo"] >>= fun item ->
		print_string ("\n"^item) ; *)

		let keylist = getkeylist path in 
    Printf.printf "no. of keys= %d" (List.length keylist);
    let stime = Unix.gettimeofday() in
		ignore @@ getvalue keylist b_master;
    let etime = Unix.gettimeofday() in
    let diff = etime -. stime in
    print_string "\ntotal time taken = ";
    print_string "\n\n\n";
    print_float diff;

    Lwt.return_unit
