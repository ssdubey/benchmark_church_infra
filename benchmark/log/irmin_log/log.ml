open Lwt.Infix

module Time : sig
  type t

  val t : t Irmin.Type.t
  val compare : t -> t -> int
  val get_time : unit -> t

end = struct
  type t = float

  let t = Irmin.Type.float

  let compare = Float.compare

  let get_time () = Unix.gettimeofday ()
end

type ('a, 'b, 'c) log_item = { time : 'a ; msg : 'b ; prev : 'c option }

type ('a, 'b, 'c) item =
  | Value of ('a, 'b, 'c) log_item
  | Merge of ('a, 'b, 'c) log_item list


module Log_item (K : Irmin.Hash.S) (V : Irmin.Type.S) :
  Irmin.Type.S with type t = (Time.t, V.t, K.t) log_item = struct
  
  type t = (Time.t, V.t, K.t) log_item
  
  let t = let open Irmin.Type in
    record "t" (fun time msg prev -> {time; msg; prev})
    |+ field "time" Time.t (fun r -> r.time)
    |+ field "msg" V.t (fun r -> r.msg)
    |+ field "prev" (option K.t) (fun r -> r.prev)
    |> sealr
end

module Item (K : Irmin.Hash.S) (V : Irmin.Type.S) :
  Irmin.Type.S with type t = (Time.t, V.t, K.t) item = struct

  module L = Log_item(K)(V)

  type t = (Time.t, V.t, K.t) item

  let t = let open Irmin.Type in
    variant "t" (fun value merge -> function Value v -> value v | Merge l -> merge l)
    |~ case1 "Value" L.t (fun v -> Value v)
    |~ case1 "Merge" (list L.t) (fun l -> Merge l)
    |> sealv

end

module Store_connect (C : Irmin.CONTENT_ADDRESSABLE_STORE_MAKER) (K : Irmin.Hash.S) (V : Irmin.Type.S) () = struct
  include C(K)(Item(K)(V))
    
  let create = ref (v (Irmin_scylla.config "51.159.31.36"))
    
end

module Log_store (C : Irmin.CONTENT_ADDRESSABLE_STORE_MAKER) (K : Irmin.Hash.S) (V : Irmin.Type.S) = struct
 
  (* module Store = struct
    include C(K)(Item(K)(V))
    
    let create () = (v (Irmin_scylla.config "51.159.31.36"))
      
  end *)

  module Store = Store_connect(C)(K)(V) ()

  let append ?prev msg = 
    !(Store.create) >>= fun store ->
    Store.batch store (fun t -> Store.add t (Value {time = Time.get_time(); msg; prev}))

  let read_key k = 
    !(Store.create) >>= fun store -> 
    Store.find store k >>= function
    | None -> failwith "Not found"
    | Some v -> Lwt.return v

  let sort l =
    List.sort (fun i1 i2 -> Time.compare i2.time i1.time) l

end

module Type (C : Irmin.CONTENT_ADDRESSABLE_STORE_MAKER) (K : Irmin.Hash.S) (V : Irmin.Type.S) : 
  Irmin.Contents.S with type t = K.t = struct

  type t = K.t

  let t = K.t

  include Log_store(C)(K)(V)
  
  let merge ~old:_ v1 v2 = 
    let open Irmin.Merge in
    !(Store.create) >>= fun store ->
    Store.find store v1 >>= fun v1 ->
    Store.find store v2 >>= fun v2 ->
    let lv1 = match v1 with
      | None -> []
      | Some (Value v) -> [v]
      | Some (Merge lv) -> lv
    in
    let lv2 = match v2 with
      | None -> []
      | Some (Value v) -> [v]
      | Some (Merge lv) -> lv
    in
    Store.batch store (fun t -> Store.add t (Merge (sort @@ lv1 @ lv2))) >>= fun m ->
    ok m

  let merge = Irmin.Merge.(option (v t merge))

end

module type S = sig
  include Containers.S

  type value
  type cursor
  type time

  val append : t -> path:key -> value -> unit Lwt.t
  val get_cursor : t -> path:key -> cursor option Lwt.t
  val read : cursor -> num_items:int -> (value list * cursor option) Lwt.t
  val read_all : t -> path:key -> value list Lwt.t
  val at_time : cursor -> time option
  val is_earlier : cursor -> than:cursor -> bool option
  val is_later : cursor -> than:cursor -> bool option

end

module Make (Backend : Irmin.S_MAKER) (M : Irmin.Metadata.S) (P : Irmin.Path.S) (B : Irmin.Branch.S) (H : Irmin.Hash.S)
            (C : Irmin.CONTENT_ADDRESSABLE_STORE_MAKER) (K : Irmin.Hash.S) (V : Irmin.Type.S) : sig
  include S with type value = V.t
             and type key = P.t
             and type branch = B.t 
end = struct
  module L = Log_store(C)(K)(V)
  
  module Repo = Containers.Make(Backend)(M)(Type(C)(K)(V))(P)(B)(H)
  include Repo
  
  module Set_elt = struct
    type t = K.t

    let compare h1 h2 = K.short_hash h1 - K.short_hash h2
  end

  module HashSet = Set.Make(Set_elt)

  type value = V.t

  type cursor =
    { seen : HashSet.t ;
      cache : (Time.t, V.t, K.t) log_item list ;
      branch : t
    }

  type time = Time.t

  let append t ~path e = 
    Store.find t path >>= fun prev ->
    L.append ?prev e >>= fun v ->
    Store.set_exn ~info:(Irmin_unix.info "append") t path v

  let get_cursor branch ~path =
    let mk_cursor k cache = Lwt.return @@ Some {seen = HashSet.singleton k; cache; branch} in
    Store.find branch path >>= function
    | None -> Lwt.return None
    | Some k ->
      L.read_key k >>= function
      | Value v -> mk_cursor k [v]
      | Merge l -> mk_cursor k l

  let rec read_log cursor num_items acc =
    let open L in
    if num_items <= 0 then Lwt.return (List.rev acc, Some cursor)
    else begin
      match cursor.cache with
      | [] -> Lwt.return (List.rev acc, None)
      | {msg; prev = None; _}::xs ->
        read_log {cursor with cache = xs} (num_items - 1) (msg::acc)
      | {msg; prev = Some pk; _}::xs ->
        if HashSet.mem pk cursor.seen then
          read_log {cursor with cache = xs} (num_items - 1) (msg::acc)
        else
          let seen = HashSet.add pk cursor.seen in
          read_key pk >>= function
          | Value v ->
            read_log {cursor with seen; cache = sort (v::xs)}
              (num_items - 1) (msg::acc)
          | Merge l ->
            read_log {cursor with seen; cache = sort (l @ xs)}
              (num_items - 1) (msg::acc)
    end

  let read cursor ~num_items =
    read_log cursor num_items []

  let read_all t ~path =
    get_cursor t ~path >>= function
    | None -> Lwt.return []
    | Some cursor ->
      read cursor ~num_items:max_int >>= fun (log, _) ->
      Lwt.return log

  let at_time {cache; _} =
    match cache with
    | [] -> None
    | {time; _}::_ -> Some time

  let is_earlier c1 ~than:c2 =
    match at_time c1, at_time c2 with
    | Some t1, Some t2 -> Some (Time.compare t1 t2 < 0)
    | _ -> None

  let is_later c1 ~than:c2 =
    match at_time c1, at_time c2 with  
    | Some t1, Some t2 -> Some (Time.compare t1 t2 > 0)
    | _ -> None

end

module Quick (V : Irmin.Type.S) : sig 
  include S with type value = V.t
             and type key = string list
             and type branch = string
end = struct
  module CAS_Maker = Irmin.Content_addressable (Irmin_scylla.Append_only)

  module Repo = Make(Irmin_scylla.Make)(Irmin.Metadata.None)(Irmin.Path.String_list)(Irmin.Branch.String)(Irmin.Hash.SHA1)
                    (CAS_Maker)(Irmin.Hash.SHA1)(V)
  include Repo
end

