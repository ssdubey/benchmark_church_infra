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

module Make (Backend : Irmin.S_MAKER)
            (M : Irmin.Metadata.S)
            (P : Irmin.Path.S)
            (B : Irmin.Branch.S)
            (H : Irmin.Hash.S)
            (C : Irmin.CONTENT_ADDRESSABLE_STORE_MAKER) 
            (K : Irmin.Hash.S) 
            (V : Irmin.Type.S)
  :
    S with type value = V.t
       and type key = P.t
       and type branch = B.t


module Quick (V : Irmin.Type.S) : S with type value = V.t
                              and type key = string list
                              and type branch = string
  (** With suitable instantiations to quickly use log *)
