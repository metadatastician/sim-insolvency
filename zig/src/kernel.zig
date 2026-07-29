// SPDX-License-Identifier: PMPL-2.0-or-later
const std = @import("std");
pub const ports = @import("ports.zig");

pub const abi_version: u32 = 1;
pub const app_version = "0.1.0-phase-a";
pub const scenario_id = "morrow-engineering-001";
pub const scenario_version = "0.1.0";
pub const rule_pack_id = "england-wales-corporate-provisional";
pub const rule_pack_version = "0.1.0";
pub const authority_cut_off = "2026-07-01";
pub const rubric_version = "0.1.0";
pub const disclaimer = "SIMULATION ONLY — completion and assessed performance; not legal advice, professional qualification, statutory authorisation, JIEB result, regulated competence, or accredited CPD.";

pub const max_events = 256;
pub const max_payload = 320;
pub const max_actor = 48;
pub const zero_digest = [_]u8{0} ** 32;

pub const Procedure = enum {
    undecided,
    informal_restructuring,
    cva,
    administration,
    cvl,
    compulsory_liquidation,
};

pub const Workstream = enum {
    engagement_and_independence,
    financial_analysis,
    advice_and_procedure_selection,
    appointment,
    estate_protection,
    assets_and_realisations,
    directors_and_records,
    investigations,
    employees,
    creditors_and_claims,
    communications,
    funds_costs_and_distributions,
    reporting,
    closure,
};

pub const WorkstreamStatus = enum {
    inactive,
    available,
    active,
    blocked,
    awaiting_response,
    at_risk,
    overdue,
    completed,
    closed_with_exception,
};

pub const EventKind = enum(u16) {
    scenario_opened,
    session_started,
    participant_joined,
    engagement_offered,
    conflict_check_requested,
    conflict_check_completed,
    evidence_requested,
    evidence_disclosed,
    evidence_withheld,
    interview_scheduled,
    interview_completed,
    claim_recorded,
    hypothesis_recorded,
    uncertainty_recorded,
    risk_recorded,
    action_proposed,
    action_authorised,
    action_rejected,
    action_completed,
    time_advanced,
    deadline_created,
    deadline_approaching,
    deadline_missed,
    procedure_considered,
    procedure_selected,
    decision_recorded,
    appointment_initiated,
    appointment_completed,
    asset_secured,
    creditor_contacted,
    investigation_opened,
    investigation_closed,
    workstream_changed,
    proposal_recorded,
    vote_recorded,
    dissent_recorded,
    reveal_authorised,
    assessment_submitted,
    assessment_completed,
    certificate_issued,
    case_closed,
};

pub const CommandError = error{
    Malformed,
    Unauthorised,
    PrerequisiteMissing,
    Untimely,
    EvidenceUnavailable,
    ResourceInsufficient,
    ProcedureDisallows,
    VersionIncompatible,
    LedgerFull,
    DuplicateIdempotency,
    IntegrityFailure,
    InvalidCertificate,
};

pub const Event = struct {
    schema_version: u16 = 1,
    sequence: u32,
    kind: EventKind,
    logical_minute: u32,
    actor_len: u8,
    actor: [max_actor]u8,
    payload_len: u16,
    payload: [max_payload]u8,
    previous_digest: [32]u8,
    digest: [32]u8,
    idempotency_key: u64,

    pub fn actorSlice(self: *const Event) []const u8 {
        return self.actor[0..self.actor_len];
    }

    pub fn payloadSlice(self: *const Event) []const u8 {
        return self.payload[0..self.payload_len];
    }
};

pub const Ledger = struct {
    events: [max_events]Event = undefined,
    len: usize = 0,

    pub fn append(
        self: *Ledger,
        kind: EventKind,
        logical_minute: u32,
        actor_text: []const u8,
        payload_text: []const u8,
        idempotency_key: u64,
    ) CommandError!*const Event {
        if (self.len >= max_events) return error.LedgerFull;
        if (actor_text.len == 0 or actor_text.len > max_actor) return error.Malformed;
        if (payload_text.len > max_payload) return error.Malformed;
        for (self.events[0..self.len]) |existing| {
            if (existing.idempotency_key == idempotency_key) return error.DuplicateIdempotency;
        }

        const previous = if (self.len == 0) zero_digest else self.events[self.len - 1].digest;
        var event: Event = .{
            .sequence = @intCast(self.len),
            .kind = kind,
            .logical_minute = logical_minute,
            .actor_len = @intCast(actor_text.len),
            .actor = [_]u8{0} ** max_actor,
            .payload_len = @intCast(payload_text.len),
            .payload = [_]u8{0} ** max_payload,
            .previous_digest = previous,
            .digest = undefined,
            .idempotency_key = idempotency_key,
        };
        @memcpy(event.actor[0..actor_text.len], actor_text);
        @memcpy(event.payload[0..payload_text.len], payload_text);
        event.digest = digestEvent(&event);
        self.events[self.len] = event;
        self.len += 1;
        return &self.events[self.len - 1];
    }

    pub fn headDigest(self: *const Ledger) [32]u8 {
        return if (self.len == 0) zero_digest else self.events[self.len - 1].digest;
    }

    pub fn verify(self: *const Ledger) bool {
        var previous = zero_digest;
        for (self.events[0..self.len], 0..) |event, index| {
            if (event.sequence != index) return false;
            if (!std.mem.eql(u8, &event.previous_digest, &previous)) return false;
            if (!std.mem.eql(u8, &event.digest, &digestEvent(&event))) return false;
            previous = event.digest;
        }
        return true;
    }
};

fn digestEvent(event: *const Event) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(&event.previous_digest);
    hash.update(std.mem.asBytes(&event.schema_version));
    hash.update(std.mem.asBytes(&event.sequence));
    const kind: u16 = @intFromEnum(event.kind);
    hash.update(std.mem.asBytes(&kind));
    hash.update(std.mem.asBytes(&event.logical_minute));
    hash.update(event.actorSlice());
    hash.update(event.payloadSlice());
    hash.update(std.mem.asBytes(&event.idempotency_key));
    var out: [32]u8 = undefined;
    hash.final(&out);
    return out;
}

pub const ConsequenceReport = struct {
    assets_preserved: i32 = 50,
    business_continuity: i32 = 50,
    evidence_preserved: i32 = 50,
    creditor_impact: i32 = 50,
    employee_impact: i32 = 50,
    cost_units: u32 = 0,
    elapsed_minutes: u32 = 0,
};

pub const CompetencyResult = struct {
    information_gathering: u8 = 0,
    procedure_comparison: u8 = 0,
    evidence_use: u8 = 0,
    uncertainty_handling: u8 = 0,
    prioritisation: u8 = 0,
    timeliness: u8 = 0,
    record_quality: u8 = 0,
    ethical_reasoning: u8 = 0,
    critical_error: bool = false,

    pub fn threshold(self: CompetencyResult) bool {
        return !self.critical_error and
            self.information_gathering >= 2 and
            self.procedure_comparison >= 2 and
            self.evidence_use >= 2 and
            self.uncertainty_handling >= 2 and
            self.timeliness >= 2 and
            self.record_quality >= 2 and
            self.ethical_reasoning >= 2;
    }
};

pub const Session = struct {
    seed: u64,
    logical_minute: u32 = 0,
    resources: i32 = 100,
    procedure: Procedure = .undecided,
    submitted: bool = false,
    closed: bool = false,
    evidence_count: u16 = 0,
    claims: u16 = 0,
    hypotheses: u16 = 0,
    uncertainties: u16 = 0,
    risks: u16 = 0,
    considered: u8 = 0,
    reasons: u16 = 0,
    communications: u16 = 0,
    protected_assets: bool = false,
    protected_records: bool = false,
    investigation_open: bool = false,
    workstreams: [14]WorkstreamStatus = [_]WorkstreamStatus{.inactive} ** 14,
    ledger: Ledger = .{},
    consequence: ConsequenceReport = .{},
    next_key: u64 = 1,

    pub fn init(seed: u64) CommandError!Session {
        var self: Session = .{ .seed = seed };
        self.workstreams[@intFromEnum(Workstream.engagement_and_independence)] = .active;
        self.workstreams[@intFromEnum(Workstream.financial_analysis)] = .available;
        self.workstreams[@intFromEnum(Workstream.advice_and_procedure_selection)] = .available;
        self.workstreams[@intFromEnum(Workstream.communications)] = .available;
        _ = try self.emit(.scenario_opened, "kernel", "morrow-engineering-001");
        _ = try self.emit(.session_started, "kernel", "assessment;seed-recorded");
        _ = try self.emit(.participant_joined, "learner", "role=case-lead");
        _ = try self.emit(.evidence_disclosed, "scenario", "initial:engagement-email,cash-summary,director-statements");
        self.evidence_count = 3;
        return self;
    }

    fn emit(self: *Session, kind: EventKind, actor: []const u8, payload: []const u8) CommandError!*const Event {
        const key = self.next_key;
        self.next_key += 1;
        return self.ledger.append(kind, self.logical_minute, actor, payload, key);
    }

    pub fn completeConflictCheck(self: *Session) CommandError!void {
        if (self.submitted) return error.Untimely;
        _ = try self.emit(.conflict_check_requested, "learner", "morrow-and-connected-parties");
        _ = try self.emit(.conflict_check_completed, "kernel", "no-known-conflict;scope-limited");
        self.workstreams[@intFromEnum(Workstream.engagement_and_independence)] = .completed;
        _ = try self.emit(.workstream_changed, "kernel", "engagement-and-independence=completed");
    }

    pub fn requestEvidence(self: *Session, request: []const u8, cost: i32) CommandError!void {
        if (self.submitted or request.len == 0) return error.Malformed;
        if (self.resources < cost) return error.ResourceInsufficient;
        self.resources -= cost;
        self.consequence.cost_units += @intCast(cost);
        _ = try self.emit(.evidence_requested, "learner", request);
        self.logical_minute += 30;
        self.consequence.elapsed_minutes = self.logical_minute;
        if (std.mem.eql(u8, request, "bank-security-records")) {
            self.evidence_count += 2;
            _ = try self.emit(.evidence_disclosed, "scenario", "bank-statements;security-particulars");
        } else if (std.mem.eql(u8, request, "management-accounts-cashflow")) {
            self.evidence_count += 2;
            _ = try self.emit(.evidence_disclosed, "scenario", "draft-management-accounts;13-week-cashflow");
        } else if (std.mem.eql(u8, request, "employee-hmrc-position")) {
            self.evidence_count += 2;
            _ = try self.emit(.evidence_disclosed, "scenario", "employee-schedule;hmrc-arrears-letter");
        } else if (std.mem.eql(u8, request, "purchaser-funding")) {
            self.evidence_count += 1;
            _ = try self.emit(.evidence_disclosed, "scenario", "purchaser-indicative-letter;funding-unverified");
        } else if (std.mem.eql(u8, request, "connected-payment-records")) {
            self.evidence_count += 1;
            _ = try self.emit(.evidence_disclosed, "scenario", "payment-ledger-and-director-explanation");
        } else {
            _ = try self.emit(.evidence_withheld, "scenario", "not-available-within-bounded-case");
        }
        try self.applyTimedEvents();
    }

    pub fn recordClaim(self: *Session, text: []const u8) CommandError!void {
        if (self.submitted or text.len == 0) return error.Malformed;
        self.claims += 1;
        _ = try self.emit(.claim_recorded, "learner", text);
    }

    pub fn recordHypothesis(self: *Session, text: []const u8) CommandError!void {
        if (self.submitted or text.len == 0) return error.Malformed;
        self.hypotheses += 1;
        _ = try self.emit(.hypothesis_recorded, "learner", text);
    }

    pub fn recordUncertainty(self: *Session, text: []const u8) CommandError!void {
        if (self.submitted or text.len == 0) return error.Malformed;
        self.uncertainties += 1;
        _ = try self.emit(.uncertainty_recorded, "learner", text);
    }

    pub fn recordRisk(self: *Session, text: []const u8) CommandError!void {
        if (self.submitted or text.len == 0) return error.Malformed;
        self.risks += 1;
        _ = try self.emit(.risk_recorded, "learner", text);
    }

    pub fn consider(self: *Session, procedure: Procedure, reason: []const u8) CommandError!void {
        if (self.submitted or procedure == .undecided or reason.len == 0) return error.Malformed;
        self.considered +|= @as(u8, 1) << @intCast(@intFromEnum(procedure) - 1);
        self.reasons += 1;
        _ = try self.emit(.procedure_considered, "learner", reason);
    }

    pub fn contactCreditor(self: *Session, text: []const u8) CommandError!void {
        if (self.submitted or text.len == 0) return error.Malformed;
        self.communications += 1;
        _ = try self.emit(.creditor_contacted, "learner", text);
    }

    pub fn selectProcedure(self: *Session, procedure: Procedure, reason: []const u8) CommandError!void {
        if (self.submitted or procedure == .undecided or reason.len < 12) return error.Malformed;
        const deep_considered = @popCount(self.considered);
        if (deep_considered < 3) return error.PrerequisiteMissing;
        if (self.evidence_count < 6) return error.EvidenceUnavailable;
        self.procedure = procedure;
        self.reasons += 1;
        _ = try self.emit(.procedure_selected, "learner", @tagName(procedure));
        _ = try self.emit(.decision_recorded, "learner", reason);
        self.workstreams[@intFromEnum(Workstream.appointment)] = .active;
        self.workstreams[@intFromEnum(Workstream.estate_protection)] = .available;
        self.workstreams[@intFromEnum(Workstream.directors_and_records)] = .available;
    }

    pub fn initiateAppointment(self: *Session) CommandError!void {
        if (self.procedure != .cvl and self.procedure != .administration) return error.ProcedureDisallows;
        _ = try self.emit(.appointment_initiated, "learner", @tagName(self.procedure));
        self.logical_minute += 120;
        self.consequence.elapsed_minutes = self.logical_minute;
        _ = try self.emit(.appointment_completed, "kernel", @tagName(self.procedure));
        self.workstreams[@intFromEnum(Workstream.appointment)] = .completed;
        self.workstreams[@intFromEnum(Workstream.estate_protection)] = .active;
        self.workstreams[@intFromEnum(Workstream.assets_and_realisations)] = .available;
        self.workstreams[@intFromEnum(Workstream.directors_and_records)] = .active;
        self.workstreams[@intFromEnum(Workstream.creditors_and_claims)] = .active;
        try self.applyTimedEvents();
    }

    pub fn protectEstate(self: *Session) CommandError!void {
        if (self.procedure == .undecided) return error.PrerequisiteMissing;
        self.protected_assets = true;
        self.protected_records = true;
        self.consequence.assets_preserved += 20;
        self.consequence.evidence_preserved += 20;
        _ = try self.emit(.asset_secured, "learner", "premises;plant;books-and-records");
        self.workstreams[@intFromEnum(Workstream.estate_protection)] = .completed;
    }

    pub fn openInvestigation(self: *Session, reason: []const u8) CommandError!void {
        if (!self.protected_records) return error.PrerequisiteMissing;
        self.investigation_open = true;
        self.workstreams[@intFromEnum(Workstream.investigations)] = .active;
        _ = try self.emit(.investigation_opened, "learner", reason);
    }

    pub fn closeInvestigation(self: *Session, reason: []const u8) CommandError!void {
        if (!self.investigation_open) return error.PrerequisiteMissing;
        self.investigation_open = false;
        self.workstreams[@intFromEnum(Workstream.investigations)] = .completed;
        _ = try self.emit(.investigation_closed, "learner", reason);
    }

    pub fn advance(self: *Session, minutes: u32) CommandError!void {
        if (self.submitted or minutes == 0 or minutes > 10_080) return error.Malformed;
        self.logical_minute += minutes;
        self.consequence.elapsed_minutes = self.logical_minute;
        _ = try self.emit(.time_advanced, "learner", "deliberate-time-allocation");
        try self.applyTimedEvents();
    }

    fn applyTimedEvents(self: *Session) CommandError!void {
        if (self.logical_minute >= 240 and self.communications == 0) {
            self.workstreams[@intFromEnum(Workstream.communications)] = .at_risk;
            _ = try self.emit(.deadline_approaching, "kernel", "secured-creditor-response-window");
        }
        if (self.logical_minute >= 480 and !self.protected_assets) {
            self.consequence.assets_preserved -= 20;
            self.consequence.evidence_preserved -= 10;
            self.workstreams[@intFromEnum(Workstream.estate_protection)] = .overdue;
            _ = try self.emit(.deadline_missed, "kernel", "asset-and-record-protection-delay");
        }
        if (self.logical_minute >= 720 and self.procedure == .undecided) {
            self.procedure = .compulsory_liquidation;
            self.consequence.business_continuity -= 35;
            self.consequence.creditor_impact -= 20;
            _ = try self.emit(.procedure_selected, "external-creditor", "compulsory-liquidation-consequence");
        }
    }

    pub fn completeBranch(self: *Session) CommandError!void {
        if (self.procedure != .cvl and self.procedure != .administration) return error.ProcedureDisallows;
        if (!self.protected_assets) return error.PrerequisiteMissing;
        self.workstreams[@intFromEnum(Workstream.assets_and_realisations)] = .completed;
        self.workstreams[@intFromEnum(Workstream.employees)] = .completed;
        self.workstreams[@intFromEnum(Workstream.creditors_and_claims)] = .completed;
        self.workstreams[@intFromEnum(Workstream.funds_costs_and_distributions)] = .completed;
        self.workstreams[@intFromEnum(Workstream.reporting)] = .completed;
        self.workstreams[@intFromEnum(Workstream.closure)] = .available;
        if (self.procedure == .administration) {
            self.consequence.business_continuity += 20;
            _ = try self.emit(.action_completed, "learner", "administration-proposals-and-bounded-sale-review");
        } else {
            self.consequence.creditor_impact += 10;
            _ = try self.emit(.action_completed, "learner", "cvl-assets-claims-reporting-distribution-abstraction");
        }
    }

    pub fn assess(self: *Session) CommandError!CompetencyResult {
        if (self.submitted) return error.Untimely;
        self.submitted = true;
        _ = try self.emit(.assessment_submitted, "learner", "final;unresolved-items-acknowledged");
        var result: CompetencyResult = .{};
        result.information_gathering = score(self.evidence_count, 5, 8);
        result.procedure_comparison = score(@popCount(self.considered), 3, 5);
        result.evidence_use = score(self.claims + self.hypotheses, 2, 5);
        result.uncertainty_handling = score(self.uncertainties + self.risks, 2, 5);
        result.prioritisation = if (self.protected_assets) 3 else if (self.logical_minute < 480) 2 else 0;
        result.timeliness = if (self.logical_minute < 480) 3 else if (self.logical_minute < 720) 2 else 0;
        result.record_quality = score(self.reasons, 4, 7);
        result.ethical_reasoning = if (self.workstreams[@intFromEnum(Workstream.engagement_and_independence)] == .completed) 3 else 0;
        result.critical_error = self.procedure == .compulsory_liquidation and self.claims == 0;
        _ = try self.emit(.assessment_completed, "assessor", if (result.threshold()) "threshold-demonstrated" else "threshold-not-yet-demonstrated");
        return result;
    }

    pub fn close(self: *Session) CommandError!void {
        if (!self.submitted) return error.PrerequisiteMissing;
        self.closed = true;
        self.workstreams[@intFromEnum(Workstream.closure)] = .completed;
        _ = try self.emit(.case_closed, "kernel", "bounded-case-complete");
    }
};

fn score(value: anytype, threshold: @TypeOf(value), strong: @TypeOf(value)) u8 {
    if (value >= strong) return 3;
    if (value >= threshold) return 2;
    if (value > 0) return 1;
    return 0;
}

pub const Certificate = struct {
    result_class: []const u8,
    ledger_digest: [32]u8,
    certificate_digest: [32]u8,
    signature: [32]u8,
    critical_error: bool,
};

pub fn issueCertificate(session: *Session, result: CompetencyResult, learner: []const u8, key: []const u8) CommandError!Certificate {
    if (!session.submitted or learner.len == 0 or key.len == 0) return error.PrerequisiteMissing;
    const certificate = try makeCertificate(session.ledger.headDigest(), result, learner, key);
    _ = try session.emit(.certificate_issued, "issuer", certificate.result_class);
    return certificate;
}

pub fn certificateForOutcome(outcome: GoldenOutcome, learner: []const u8, key: []const u8) CommandError!Certificate {
    return makeCertificate(outcome.digest, outcome.result, learner, key);
}

pub fn certificateFromFields(ledger_digest: [32]u8, result: CompetencyResult, learner: []const u8, key: []const u8) CommandError!Certificate {
    return makeCertificate(ledger_digest, result, learner, key);
}

fn makeCertificate(ledger_digest: [32]u8, result: CompetencyResult, learner: []const u8, key: []const u8) CommandError!Certificate {
    if (learner.len == 0 or key.len == 0) return error.PrerequisiteMissing;
    const class = if (result.critical_error) "invalidated" else if (result.threshold()) "threshold-demonstrated" else "threshold-not-yet-demonstrated";
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(learner);
    hash.update(scenario_id);
    hash.update(scenario_version);
    hash.update(rule_pack_id);
    hash.update(rule_pack_version);
    hash.update(authority_cut_off);
    hash.update(rubric_version);
    hash.update(class);
    hash.update(std.mem.asBytes(&result.information_gathering));
    hash.update(std.mem.asBytes(&result.procedure_comparison));
    hash.update(std.mem.asBytes(&result.evidence_use));
    hash.update(std.mem.asBytes(&result.uncertainty_handling));
    hash.update(std.mem.asBytes(&result.prioritisation));
    hash.update(std.mem.asBytes(&result.timeliness));
    hash.update(std.mem.asBytes(&result.record_quality));
    hash.update(std.mem.asBytes(&result.ethical_reasoning));
    hash.update(std.mem.asBytes(&result.critical_error));
    hash.update(&ledger_digest);
    hash.update(app_version);
    hash.update(disclaimer);
    var cert_digest: [32]u8 = undefined;
    hash.final(&cert_digest);
    const signature = hmacSha256(key, &cert_digest);
    return .{
        .result_class = class,
        .ledger_digest = ledger_digest,
        .certificate_digest = cert_digest,
        .signature = signature,
        .critical_error = result.critical_error,
    };
}

pub fn verifyCertificate(cert: Certificate, key: []const u8) bool {
    if (key.len == 0) return false;
    const expected = hmacSha256(key, &cert.certificate_digest);
    return std.crypto.timing_safe.eql([32]u8, expected, cert.signature);
}

fn hmacSha256(key: []const u8, message: []const u8) [32]u8 {
    const block_size = 64;
    var normalized = [_]u8{0} ** block_size;
    if (key.len > block_size) {
        var key_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(key, &key_hash, .{});
        @memcpy(normalized[0..key_hash.len], &key_hash);
    } else {
        @memcpy(normalized[0..key.len], key);
    }
    var inner_key: [block_size]u8 = undefined;
    var outer_key: [block_size]u8 = undefined;
    for (normalized, 0..) |byte, index| {
        inner_key[index] = byte ^ 0x36;
        outer_key[index] = byte ^ 0x5c;
    }
    var inner = std.crypto.hash.sha2.Sha256.init(.{});
    inner.update(&inner_key);
    inner.update(message);
    var inner_digest: [32]u8 = undefined;
    inner.final(&inner_digest);
    var outer = std.crypto.hash.sha2.Sha256.init(.{});
    outer.update(&outer_key);
    outer.update(&inner_digest);
    var output: [32]u8 = undefined;
    outer.final(&output);
    return output;
}

pub const GoldenRun = enum {
    cvl_competent_standard,
    cvl_competent_alternative,
    administration_competent_standard,
    administration_competent_alternative,
    threshold_borderline,
    critical_error,
    deadline_failure,
    group_session_with_dissent,
};

pub const GoldenOutcome = struct {
    run: GoldenRun,
    result: CompetencyResult,
    consequence: ConsequenceReport,
    digest: [32]u8,
    event_count: usize,
};

pub fn runGolden(run: GoldenRun) CommandError!GoldenOutcome {
    var session = try Session.init(@as(u64, 0x4d4f52524f57) + @as(u64, @intFromEnum(run)));
    if (run != .critical_error) try session.completeConflictCheck();
    try session.requestEvidence("bank-security-records", 5);
    try session.requestEvidence("management-accounts-cashflow", 7);
    if (run != .threshold_borderline and run != .deadline_failure and run != .critical_error) {
        try session.requestEvidence("employee-hmrc-position", 5);
        try session.requestEvidence("purchaser-funding", 8);
        try session.requestEvidence("connected-payment-records", 6);
    }
    if (run != .critical_error) {
        try session.recordClaim("cash pressure is evidenced; balance-sheet position remains uncertain");
        try session.recordHypothesis("business may be viable if purchaser funding and short-term liquidity are verified");
        try session.recordUncertainty("security enforcement timing and purchaser reliability remain unresolved");
        try session.recordRisk("delay may reduce asset value and permit creditor escalation");
        if (run == .cvl_competent_alternative or run == .administration_competent_alternative) {
            try session.recordClaim("alternative route preserves a different cost-control-risk balance");
        }
    }
    try session.consider(.informal_restructuring, "conditional on funding, forbearance and reliable information");
    try session.consider(.cva, "bounded alternative requiring sustainable contributions and viable operations");
    try session.consider(.administration, "purpose and appointment route assessed against rescue or sale evidence");
    try session.consider(.cvl, "cessation and orderly realisation assessed if rescue evidence is insufficient");
    if (run != .deadline_failure and run != .critical_error) {
        try session.contactCreditor("secured creditor and HMRC contacted with caveated options update");
    }
    if (run == .deadline_failure or run == .critical_error) {
        try session.advance(760);
    } else {
        const selected: Procedure = switch (run) {
            .administration_competent_standard, .administration_competent_alternative => .administration,
            else => .cvl,
        };
        try session.selectProcedure(selected, "selected after evidence-linked comparison; uncertainty, costs, control and downside recorded");
        try session.initiateAppointment();
        try session.protectEstate();
        if (run != .threshold_borderline) {
            try session.openInvestigation("connected payment and director loan evidence justify proportionate enquiry");
            try session.closeInvestigation("bounded enquiries completed; no learner-visible legal conclusion encoded");
        }
        if (run == .group_session_with_dissent) {
            _ = try session.emit(.proposal_recorded, "participant-alpha", "proposal=administration");
            _ = try session.emit(.vote_recorded, "participant-beta", "support=cvl");
            _ = try session.emit(.dissent_recorded, "participant-beta", "cost and funding objections preserved");
            _ = try session.emit(.reveal_authorised, "facilitator", "purchaser-funding-response");
        }
        try session.completeBranch();
    }
    const result = try session.assess();
    try session.close();
    return .{
        .run = run,
        .result = result,
        .consequence = session.consequence,
        .digest = session.ledger.headDigest(),
        .event_count = session.ledger.len,
    };
}

test "ledger replay chain is deterministic and tamper evident" {
    const first = try runGolden(.cvl_competent_standard);
    const second = try runGolden(.cvl_competent_standard);
    try std.testing.expectEqualSlices(u8, &first.digest, &second.digest);
    try std.testing.expectEqual(first.event_count, second.event_count);

    var session = try Session.init(42);
    try std.testing.expect(session.ledger.verify());
    session.ledger.events[0].payload[0] ^= 1;
    try std.testing.expect(!session.ledger.verify());
}

test "all eight golden runs are deterministic and distinct where intended" {
    const runs = [_]GoldenRun{
        .cvl_competent_standard,
        .cvl_competent_alternative,
        .administration_competent_standard,
        .administration_competent_alternative,
        .threshold_borderline,
        .critical_error,
        .deadline_failure,
        .group_session_with_dissent,
    };
    var previous: ?[32]u8 = null;
    for (runs) |run| {
        const outcome = try runGolden(run);
        const replay = try runGolden(run);
        try std.testing.expectEqualSlices(u8, &outcome.digest, &replay.digest);
        try std.testing.expect(outcome.event_count >= 15);
        if (previous) |digest| try std.testing.expect(!std.mem.eql(u8, &digest, &outcome.digest));
        previous = outcome.digest;
    }
}

test "competence is separate from consequence" {
    const cvl = try runGolden(.cvl_competent_standard);
    const administration = try runGolden(.administration_competent_standard);
    try std.testing.expect(cvl.result.threshold());
    try std.testing.expect(administration.result.threshold());
    try std.testing.expect(cvl.consequence.business_continuity != administration.consequence.business_continuity);
}

test "certificate signature detects tampering" {
    var session = try Session.init(91);
    try session.completeConflictCheck();
    try session.requestEvidence("bank-security-records", 5);
    try session.requestEvidence("management-accounts-cashflow", 5);
    try session.requestEvidence("employee-hmrc-position", 5);
    try session.recordClaim("evidence-linked claim");
    try session.recordHypothesis("alternative hypothesis");
    try session.recordUncertainty("material uncertainty");
    try session.recordRisk("timing risk");
    try session.consider(.cvl, "orderly cessation and realisation");
    try session.consider(.administration, "rescue or sale purpose");
    try session.consider(.cva, "viability and contributions");
    try session.selectProcedure(.cvl, "evidence-linked selection with uncertainty and alternatives recorded");
    try session.initiateAppointment();
    try session.protectEstate();
    try session.completeBranch();
    const result = try session.assess();
    const cert = try issueCertificate(&session, result, "learner-001", "test-key-not-for-production");
    try std.testing.expect(verifyCertificate(cert, "test-key-not-for-production"));
    var changed = cert;
    changed.certificate_digest[0] ^= 1;
    try std.testing.expect(!verifyCertificate(changed, "test-key-not-for-production"));
}

test "disclosure is monotonic" {
    var session = try Session.init(55);
    const initial = session.evidence_count;
    try session.requestEvidence("bank-security-records", 1);
    const after = session.evidence_count;
    try session.requestEvidence("unknown-request", 1);
    try std.testing.expect(after >= initial);
    try std.testing.expect(session.evidence_count >= after);
}
