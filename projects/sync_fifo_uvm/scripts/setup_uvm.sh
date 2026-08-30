#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UVM_DIR="${PROJECT_ROOT}/.deps/uvm"
UVM_REPOSITORY="https://github.com/verilator/uvm.git"
UVM_COMMIT="656f20d087370a7c742e00188d20bbf30fa95339"
UVM_VERSION_STRING="Accellera:1800.2:UVM:2020.3.1"
REQUIRED_UVM_FILES=(
    "src/uvm_pkg.sv"
    "src/uvm_macros.svh"
    "src/base/uvm_version.svh"
    "src/dpi/uvm_dpi.cc"
)

if ! command -v git >/dev/null 2>&1; then
    printf 'ERROR: Git is required to install the pinned UVM dependency.\n' >&2
    exit 1
fi

mkdir -p "${PROJECT_ROOT}/.deps"
FRESH_CLONE=0

if [[ ! -d "${UVM_DIR}/.git" ]]; then
    if [[ -e "${UVM_DIR}" ]]; then
        printf 'ERROR: %s exists but is not a Git repository.\n' "${UVM_DIR}" >&2
        exit 1
    fi

    git clone --filter=blob:none "${UVM_REPOSITORY}" "${UVM_DIR}"
    FRESH_CLONE=1
else
    CURRENT_ORIGIN="$(git -C "${UVM_DIR}" remote get-url origin 2>/dev/null || true)"
    if [[ "${CURRENT_ORIGIN}" != "${UVM_REPOSITORY}" ]]; then
        printf 'ERROR: existing UVM repository has unexpected origin.\n' >&2
        printf 'expected: %s\n' "${UVM_REPOSITORY}" >&2
        printf 'actual:   %s\n' "${CURRENT_ORIGIN:-<missing>}" >&2
        exit 1
    fi
fi

# Reuse a verified local checkout; fetch only when the pinned commit is absent.
CURRENT_COMMIT="$(git -C "${UVM_DIR}" rev-parse HEAD 2>/dev/null || true)"
if [[ "${CURRENT_COMMIT}" != "${UVM_COMMIT}" ]]; then
    git -C "${UVM_DIR}" fetch --depth 1 origin "${UVM_COMMIT}"
    git -C "${UVM_DIR}" checkout --detach "${UVM_COMMIT}"
    SETUP_SOURCE="network fetch"
elif [[ "${FRESH_CLONE}" -eq 1 ]]; then
    SETUP_SOURCE="network clone"
else
    SETUP_SOURCE="local cache"
fi

ACTUAL_COMMIT="$(git -C "${UVM_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${UVM_COMMIT}" ]]; then
    printf 'ERROR: UVM commit verification failed.\n' >&2
    printf 'expected: %s\n' "${UVM_COMMIT}" >&2
    printf 'actual:   %s\n' "${ACTUAL_COMMIT}" >&2
    exit 1
fi

if ! git -C "${UVM_DIR}" diff --quiet ||
   ! git -C "${UVM_DIR}" diff --cached --quiet; then
    printf 'ERROR: tracked files in the pinned UVM dependency have local modifications.\n' >&2
    printf 'Inspect them with: git -C %s status --short\n' "${UVM_DIR}" >&2
    exit 1
fi

for required_file in "${REQUIRED_UVM_FILES[@]}"; do
    if [[ ! -f "${UVM_DIR}/${required_file}" ]]; then
        printf 'ERROR: required UVM file is missing: %s\n' \
               "${UVM_DIR}/${required_file}" >&2
        exit 1
    fi
done

if ! grep -Fq "${UVM_VERSION_STRING}" "${UVM_DIR}/src/base/uvm_version.svh"; then
    printf 'ERROR: pinned UVM source does not contain expected version string: %s\n' \
           "${UVM_VERSION_STRING}" >&2
    exit 1
fi

printf 'UVM SETUP PASS\n'
printf 'repository: %s\n' "${UVM_REPOSITORY}"
printf 'commit:     %s\n' "${ACTUAL_COMMIT}"
printf 'version:    %s\n' "${UVM_VERSION_STRING}"
printf 'source:     %s\n' "${SETUP_SOURCE}"
printf 'tracked:    clean\n'
printf 'UVM_HOME:   %s\n' "${UVM_DIR}"
