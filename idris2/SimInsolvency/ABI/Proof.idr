-- SPDX-License-Identifier: PMPL-2.0-or-later
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
module SimInsolvency.ABI.Proof

import Data.Nat

%default total

public export
data ProofVerdict = Unknown | Proved | Disproved | TimedOut | ProofError

public export
record ProofGoal where
  constructor MkProofGoal
  schemaVersion : Nat
  requestId : String
  sessionId : String
  goal : String
  context : String
  preferredProverKind : String
  preferredProverName : String
  timeoutMs : Nat
  minimumTrustLevel : Nat
  crossCheck : Bool
  requestDiagnostics : Bool
  trackAxioms : Bool
  generateCertificate : Bool
  metadataJson : String

public export
record ProofReceipt where
  constructor MkProofReceipt
  attemptId : String
  octadKey : String
  prover : String
  verdict : ProofVerdict
  startedAt : String
  latencyMs : Nat
  axiomCost : Nat
  certificateDigest : String
  proverBinaryHash : String
  confidencePermille : Nat

public export
ValidProofGoal : ProofGoal -> Type
ValidProofGoal p =
  (p.schemaVersion = 1,
   Not (p.requestId = ""),
   Not (p.goal = ""),
   LTE 1 p.timeoutMs,
   LTE p.timeoutMs 300000,
   LTE p.minimumTrustLevel 4)

public export
ValidProvedReceipt : ProofReceipt -> Type
ValidProvedReceipt r =
  case r.verdict of
    Proved => (Not (r.certificateDigest = ""), Not (r.proverBinaryHash = ""))
    _ => Not (r.proverBinaryHash = "")
