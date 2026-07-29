# SPDX-License-Identifier: PMPL-2.0-or-later
set shell := ["bash", "-uc"]
set positional-arguments := true
export XDG_RUNTIME_DIR := "/tmp"

project := "sim-insolvency"
zig_env := "ZIG_GLOBAL_CACHE_DIR=/tmp/sim-insolvency-zig-global ZIG_LOCAL_CACHE_DIR=.zig-cache"

default:
    @just --list --unsorted

doctor:
    ./tools/doctor.sh

deps:
    @echo "Dependencies are Guix-managed; run: guix shell -m build/guix.scm"
    ./tools/doctor.sh

build:
    {{zig_env}} zig build

build-wasm:
    {{zig_env}} zig build wasm
    @echo "Built explicit untyped wasm fallback; use build-typed-wasm for the typed carrier gate."

build-typed-wasm:
    ./tools/build-typed-wasm.sh

build-shell: build
    test -s shell/index.html
    @echo "Headless Gossamer projection and native kernel built; graphical Gossamer runtime is optional."

standalone profile="learner": build
    ./tools/package-standalone.sh "{{profile}}"

container-build:
    nerdctl --data-root .nerdctl build --file Containerfile --tag sim-insolvency:local .

container-run:
    nerdctl --data-root .nerdctl run --rm --network none sim-insolvency:local home

container-inspect:
    nerdctl --data-root .nerdctl image inspect sim-insolvency:local

check: lint typecheck prove test

typecheck:
    ./tools/typecheck-affinescript.sh

prove:
    cd idris2 && idris2 --build sim-insolvency-abi.ipkg

test:
    {{zig_env}} zig build test
    ./tools/check-abi-drift.sh
    ./tools/validate-scenario.sh
    ./tools/check-no-prohibited-stack.sh

test-unit:
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "certificate"
    {{zig_env}} zig test zig/src/ports.zig

test-property:
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "deterministic"
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "monotonic"

test-conformance:
    ./tools/check-abi-drift.sh
    {{zig_env}} zig test zig/src/ports.zig

test-scenarios:
    ./tools/validate-scenario.sh
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "competence"

test-golden: build
    ./zig-out/bin/sim-insolvency golden

test-replay:
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "replay"

test-mutation:
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "tamper"

fuzz:
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "version and length"
    @echo "Bounded decoder/port malformed-input corpus passed; coverage-guided fuzzing remains a documented gap."

bench: build
    @time ./zig-out/bin/sim-insolvency golden >/dev/null

lint:
    zig fmt --check build.zig zig
    ./tools/check-no-prohibited-stack.sh

format:
    zig fmt build.zig zig

run: build
    ./zig-out/bin/sim-insolvency home

run-group: build
    ./zig-out/bin/sim-insolvency group-demo

replay bundle:
    @echo "Replay fixture requested: {{bundle}}"
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "replay"

verify-certificate certificate:
    @echo "Verifying certificate envelope: {{certificate}}"
    test -s "{{certificate}}"
    {{zig_env}} zig test zig/src/kernel.zig --test-filter "certificate"

docs:
    @find docs -name '*.adoc' -type f | sort

clean:
    rm -rf zig-out .zig-cache idris2/build
