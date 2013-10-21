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

(** {2 Irminsule stores} *)

module type S = sig

  (** Base types for stores. *)

  type t
  (** Type of stores. *)

  type key
  (** Type of keys. *)

  type value
  (** Type of values. *)

  val write: t -> key -> value -> unit Lwt.t
  (** Write the contents of a buffer to the store. *)

  val read: t -> key -> value option Lwt.t
  (** Read a value from the store. *)

  val list: t -> key list Lwt.t
  (** List of the keys. *)

end

module type RAW = S with type value := IrminBuffer.t
(** Raw store. *)

module Make (R: RAW) (B: IrminBase.S): S with type value = B.t
(** Lift a raw store to a more structured one *)