-- SPDX-License-Identifier: PMPL-2.0-or-later
module SimInsolvency.ABI.Core

import Data.Nat

%default total

public export
data AbiVersion = V1

public export
record StableId where
  constructor MkStableId
  namespaceName : String
  value : String

public export
data Lifecycle
  = Authored | Available | Active | Blocked | Completed | Closed | Revoked

public export
data BoundaryStatus
  = Ok
  | InvalidVersion
  | InvalidLength
  | InvalidEncoding
  | NotAuthorised
  | NotAvailable
  | NotSupported
  | Conflict
  | IntegrityFailure
  | ResourceExhausted
  | InternalFailure

public export
record OwnedSlice where
  constructor MkOwnedSlice
  offset : Nat
  length : Nat
  capacity : Nat
  fits : LTE length capacity
