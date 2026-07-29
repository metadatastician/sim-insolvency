// SPDX-License-Identifier: PMPL-2.0-or-later
const sim = @import("sim_insolvency");

export fn sim_abi_version() u32 {
    return sim.abi_version;
}

export fn sim_scenario_id() [*]const u8 {
    return sim.scenario_id.ptr;
}

export fn sim_scenario_id_len() usize {
    return sim.scenario_id.len;
}
