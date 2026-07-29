-- SPDX-License-Identifier: PMPL-2.0-or-later
module SimInsolvency.ABI.Conformance

import SimInsolvency.ABI.Core

%default total

public export
abiVersionNumber : AbiVersion -> Nat
abiVersionNumber V1 = 1

public export
abiV1IsOne : abiVersionNumber V1 = 1
abiV1IsOne = Refl

public export
statusOrdinal : BoundaryStatus -> Nat
statusOrdinal Ok = 0
statusOrdinal InvalidVersion = 1
statusOrdinal InvalidLength = 2
statusOrdinal InvalidEncoding = 3
statusOrdinal NotAuthorised = 4
statusOrdinal NotAvailable = 5
statusOrdinal NotSupported = 6
statusOrdinal Conflict = 7
statusOrdinal IntegrityFailure = 8
statusOrdinal ResourceExhausted = 9
statusOrdinal InternalFailure = 10

public export
notSupportedOrdinal : statusOrdinal NotSupported = 6
notSupportedOrdinal = Refl
