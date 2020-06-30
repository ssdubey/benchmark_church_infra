module type S = sig
  (** Signature of the blob log *)

  include Containers.S

  type value
    (** Type of log entry *)
  
  val append : t -> path:key -> value -> unit Lwt.t
    (** Append an entry to the log *)
  
  val read_all : t -> path:key  -> value list Lwt.t
    (** Read the entire log *)

end


module Make (Backend : Irmin.S_MAKER)
            (M : Irmin.Metadata.S)
            (P : Irmin.Path.S)
            (B : Irmin.Branch.S)
            (H : Irmin.Hash.S)
            (V : Irmin.Type.S)
  :
    S with type value = V.t
       and type key = P.t
       and type branch = B.t


module Quick (V : Irmin.Type.S) : S with type value = V.t
                              and type key = string list
                              and type branch = string
  (** With suitable instantiations to quickly use blob log *)

