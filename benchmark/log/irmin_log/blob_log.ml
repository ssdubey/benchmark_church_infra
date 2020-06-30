open Lwt.Infix

module Time : sig
  type t

  val t : t Irmin.Type.t
  val compare : t -> t -> int
  val get_time : unit -> t
  val base_val : t

end = struct
  type t = float

  let t = Irmin.Type.float

  let compare = Float.compare

  let get_time () = Unix.gettimeofday ()

  let base_val = 0.0
end

module Type (V : Irmin.Type.S) : Irmin.Contents.S with type t = (V.t * Time.t) list = struct
  type t = (V.t * Time.t) list
           
  let t = Irmin.Type.(list (pair V.t Time.t))

  let compare (_, t1) (_, t2) = Time.compare t1 t2

  let newer_than timestamp entries = 
    let rec util acc = function
      | [] -> List.rev acc
      | (_,x)::_ when Time.compare x timestamp <= 0 -> List.rev acc
      | h::t -> util (h::acc) t
    in
      util [] entries

  let merge ~old v1 v2 = 
    let open Irmin.Merge.Infix in
    let ok = Irmin.Merge.ok in
    old () >>=* fun old ->
    let old = match old with None -> [] | Some o -> o in
    let ts = match old with [] -> Time.base_val | (_, t) :: _ -> t in
    let l1 = newer_than ts v1 in
    let l2 = newer_than ts v2 in
    let l3 = List.sort compare (List.rev_append l1 l2) in
    ok (List.rev_append l3 old)

  let merge = Irmin.Merge.(option (v t merge))
end

module type S = sig
  include Containers.S

  type value

  val append : t -> path:key -> value -> unit Lwt.t
  val read_all : t -> path:key -> value list Lwt.t
end

module Make (Backend : Irmin.S_MAKER) (M : Irmin.Metadata.S) (P : Irmin.Path.S) (B : Irmin.Branch.S) (H : Irmin.Hash.S) (V : Irmin.Type.S): sig
  include S with type value = V.t
             and type key = P.t
             and type branch = B.t 
end = struct
  module Repo = Containers.Make(Backend)(M)(Type(V))(P)(B)(H)
  include Repo

  type value = V.t

  let create_entry v = (v, Time.get_time())

  let append t ~path v = 
    Store.find t path >>= function
    | None -> Store.set_exn ~info:(Irmin_unix.info "creating new log") t path [create_entry v]
    | Some l -> Store.set_exn ~info:(Irmin_unix.info "adding new entry") t path (create_entry v :: l)

  let read_all t ~path = 
    Store.find t path >>= function
    | None -> Lwt.return []
    | Some l -> Lwt.return (List.map (fun (v,_) -> v) l)
end

module Quick (V : Irmin.Type.S) : sig
  include S with type value = V.t
             and type key = string list
             and type branch = string
end = Make(Irmin_unix.FS.Make)(Irmin.Metadata.None)(Irmin.Path.String_list)(Irmin.Branch.String)(Irmin.Hash.SHA1)(V)

