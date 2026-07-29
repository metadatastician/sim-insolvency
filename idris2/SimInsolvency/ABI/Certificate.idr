-- SPDX-License-Identifier: PMPL-2.0-or-later
module SimInsolvency.ABI.Certificate

import SimInsolvency.ABI.Core

%default total

public export
data ResultClass
  = Completed
  | CompletedWithFeedback
  | ThresholdDemonstrated
  | ThresholdNotYetDemonstrated
  | Invalidated

public export
record CertificateEnvelope where
  constructor MkCertificateEnvelope
  schema : AbiVersion
  learnerId : StableId
  scenarioId : StableId
  scenarioVersion : String
  rulePackId : StableId
  rulePackVersion : String
  authorityCutOff : String
  rubricVersion : String
  resultClass : ResultClass
  criticalError : Bool
  applicationVersion : String
  ledgerDigest : String
  resultDigest : String
  keyId : String
  signature : String
  disclaimer : String

public export
data IssuePermitted : CertificateEnvelope -> Type where
  IssueNonInvalid :
    (criticalError cert = False) ->
    Not (resultClass cert = Invalidated) ->
    IssuePermitted cert

public export
falseNotTrue : Not (False = True)
falseNotTrue Refl impossible

public export
criticalErrorCannotIssue :
  {cert : CertificateEnvelope} ->
  criticalError cert = True ->
  Not (IssuePermitted cert)
criticalErrorCannotIssue isTrue (IssueNonInvalid isFalse _) =
  falseNotTrue (trans (sym isFalse) isTrue)
