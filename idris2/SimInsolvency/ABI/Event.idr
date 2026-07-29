-- SPDX-License-Identifier: PMPL-2.0-or-later
module SimInsolvency.ABI.Event

import SimInsolvency.ABI.Core

%default total

public export
record EventEnvelope where
  constructor MkEventEnvelope
  schema : AbiVersion
  eventId : StableId
  sessionId : StableId
  sequence : Nat
  logicalMinute : Nat
  actorId : StableId
  kind : String
  previousDigest : String
  digest : String

public export
data Follows : EventEnvelope -> EventEnvelope -> Type where
  Next : (later.sequence = S earlier.sequence) ->
         Follows earlier later

public export
dropSucc : Nat -> Nat
dropSucc Z = Z
dropSucc (S n) = n

public export
succNotSame : (n : Nat) -> Not (S n = n)
succNotSame Z Refl impossible
succNotSame (S n) equality = succNotSame n (cong dropSucc equality)

public export
sequenceCannotStayEqual :
  {earlier, later : EventEnvelope} ->
  Follows earlier later ->
  Not (later.sequence = earlier.sequence)
sequenceCannotStayEqual (Next next) same =
  succNotSame earlier.sequence (trans (sym next) same)

public export
record ProvenanceWitness where
  constructor MkProvenanceWitness
  sourceId : StableId
  createdBy : StableId
  createdAt : Nat
