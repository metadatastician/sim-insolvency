; SPDX-License-Identifier: PMPL-2.0-or-later
;; Authoritative Guix development manifest. Usage: guix shell -m build/guix.scm

(use-modules (guix profiles))

(specifications->manifest
  (list "bash"
        "coreutils"
        "findutils"
        "git"
        "grep"
        "guile"
        "idris2"
        "just"
        "sed"
        "zig"))
