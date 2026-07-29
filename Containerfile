# SPDX-License-Identifier: PMPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# Build with nerdctl. The image requests no network at runtime and excludes
# authored hidden reality.

FROM cgr.dev/chainguard/wolfi-base:latest AS build
RUN apk add --no-cache zig
WORKDIR /src
COPY build.zig ./
COPY zig ./zig
RUN ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global ZIG_LOCAL_CACHE_DIR=/tmp/zig-local \
    zig build -Doptimize=ReleaseSafe

FROM cgr.dev/chainguard/wolfi-base:latest
LABEL org.opencontainers.image.title="Sim Insolvency"
LABEL org.opencontainers.image.description="Local-first fictional insolvency practice simulation"
LABEL org.opencontainers.image.licenses="PMPL-2.0-or-later"
LABEL org.opencontainers.image.source="https://github.com/metadatastician/sim-insolvency"
LABEL io.sim-insolvency.classification="SIMULATION-NOT-LEGAL-ADVICE"
RUN addgroup -S sim && adduser -S -D -H -G sim -u 65532 sim
WORKDIR /opt/sim-insolvency
COPY --from=build /src/zig-out/bin/sim-insolvency ./bin/sim-insolvency
COPY LICENSE README.adoc DEPENDENCIES.adoc ./
COPY shell ./shell
COPY rule-packs ./rule-packs
COPY scenarios/morrow-engineering-001/manifest/public.a2ml ./scenarios/morrow-engineering-001/manifest/public.a2ml
COPY scenarios/morrow-engineering-001/evidence/engagement-email.adoc ./scenarios/morrow-engineering-001/evidence/engagement-email.adoc
COPY scenarios/morrow-engineering-001/evidence/cash-summary.adoc ./scenarios/morrow-engineering-001/evidence/cash-summary.adoc
COPY scenarios/morrow-engineering-001/evidence/director-statements.adoc ./scenarios/morrow-engineering-001/evidence/director-statements.adoc
COPY scenarios/morrow-engineering-001/actors ./scenarios/morrow-engineering-001/actors
COPY scenarios/morrow-engineering-001/procedures ./scenarios/morrow-engineering-001/procedures
RUN chown -R sim:sim /opt/sim-insolvency
USER 65532:65532
ENV SIM_INSOLVENCY_NETWORK=disabled
ENTRYPOINT ["/opt/sim-insolvency/bin/sim-insolvency"]
CMD ["home"]
