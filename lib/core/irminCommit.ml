(*
 * Copyright (c) 2013 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Core_kernel.Std

type 'a t = {
  tree   : 'a option;
  parents: 'a list;
} with bin_io, compare, sexp

module L = Log.Make(struct let section = "COMMIT" end)

module type S = sig
  type key
  include IrminBlob.S with type key := key and type t = key t
end

module S (K: IrminKey.S) = struct

  type key = K.t

  module M = struct
    type nonrec t = K.t t
    with bin_io, compare, sexp
    let hash (t : t) = Hashtbl.hash t
    include Sexpable.To_stringable (struct type nonrec t = t with sexp end)
    let module_name = "Commit"
  end
  include M
  include Identifiable.Make (M)

  module XTree = struct
    include IrminBase.Option(K)
    let name = "tree"
  end
  module XParents = struct
    include IrminBase.List(K)
    let name = "parents"
  end
  module XCommit = struct
    include IrminBase.Pair(XTree)(XParents)
    let name = "commit"
  end

  let name = "commit"

  let to_json t =
    XCommit.to_json (t.tree, t.parents)

  let of_json j =
    let tree, parents = XCommit.of_json j in
    { tree; parents }

  let pretty t =
    XCommit.pretty (t.tree, t.parents)

  let merge ~old:_ _ _ =
    failwith "Commit.merge: TODO"

  let of_bytes str =
    IrminMisc.read bin_t (Bigstring.of_string str)

  let of_bytes_exn str =
    let buf = Bigstring.of_string str in
    bin_read_t ~pos_ref:(ref 0) buf

  let key t =
    K.of_bigarray (IrminMisc.write bin_t t)

end

module SHA1 = S(IrminKey.SHA1)

module type STORE = sig
  type key
  type value = key t
  include IrminStore.AO with type key := key
                         and type value := value
  val commit: t -> ?tree:key IrminTree.t -> parents:value list -> key Lwt.t
  val tree: t -> value -> key IrminTree.t Lwt.t option
  val parents: t -> value -> value Lwt.t list
  module Key: IrminKey.S with type t = key
  module Value: S with type key = key
end

module Make
    (K: IrminKey.S)
    (B: IrminBlob.S)
    (Tree: IrminStore.AO with type key = K.t and type value = K.t IrminTree.t)
    (Commit: IrminStore.AO with type key = K.t and type value = K.t t)
= struct

  type key = K.t
  type value = key t
  type t = Tree.t * Commit.t

  module Key = K

  module Value = S(K)

  open Lwt

  let create () =
    Tree.create () >>= fun t ->
    Commit.create () >>= fun c ->
    return (t, c)

  let add (_, t) c =
    Commit.add t c

  let read (_, t) c =
    Commit.read t c

  let read_exn (_, t) c =
    Commit.read_exn t c

  let mem (_, t) c =
    Commit.mem t c

  let tree (t, _) c =
    match c.tree with
    | None   -> None
    | Some k -> Some (Tree.read_exn t k)

  let commit (t, c) ?tree ~parents =
    begin match tree with
      | None      -> return_none
      | Some tree -> Tree.add t tree >>= fun k -> return (Some k)
    end
    >>= fun tree ->
    Lwt_list.map_p (Commit.add c) parents
    >>= fun parents ->
    Commit.add c { tree; parents }

  let parents t c =
    List.map ~f:(read_exn t) c.parents

  module Graph = IrminGraph.Make(K)

  let list t key =
    L.debugf "list %s" (K.pretty key);
    let pred k =
      read_exn t k >>= fun r -> return r.parents in
    Graph.closure pred ~min:[] ~max:[key] >>= fun g ->
    return (Graph.vertex g)

  let contents (_, t) =
    Commit.contents t

end
