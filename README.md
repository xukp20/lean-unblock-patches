# Lean 4.35.0 unblock patches

Two patches reduce waits behind earlier proofs when elaborating inductive types and generating simp congruence lemmas. The first patch checks an inductive signature early, then checks the full declaration on the original kernel chain. If the early check fails, it uses the original synchronous path. The second patch lets congruence generation try its existing local fallback when the reserved lemma is still unavailable.

The source of truth is [the Lean fork branch](https://github.com/xukp20/lean4/tree/unblocked/v4.35.0). This repository contains the two commits in Git patch format. [versions.json](versions.json) pins the upstream tag and the corresponding fork commit.

## Build and install

Use a private checkout and the pinned upstream tag. The apply script leaves the patch as worktree changes, so Lean can retain the upstream Git stamp used by its official artifacts.

```sh
git clone https://github.com/xukp20/lean-unblock-patches.git
git clone --branch v4.35.0 --depth 1 https://github.com/leanprover/lean4.git lean4-v4.35.0
git -C lean4-v4.35.0 switch --detach v4.35.0
python3 lean-unblock-patches/apply.py v4.35.0 lean4-v4.35.0
```

On Linux x86-64 with Nix flakes enabled, use Lean's oldGlibc development shell and the same LLVM bundle as the upstream release build:

```sh
root="$(pwd)"
curl -fL -o "$root/lean-llvm-x86_64-linux-gnu.tar.zst" \
  https://github.com/leanprover/lean-llvm/releases/download/23.1.0/lean-llvm-x86_64-linux-gnu.tar.zst
nix_bin="$(command -v nix)"
cd "$root/lean4-v4.35.0"
env -i HOME="$HOME" PATH=/usr/bin:/bin \
  HTTPS_PROXY="${HTTPS_PROXY:-}" HTTP_PROXY="${HTTP_PROXY:-}" \
  ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}" \
  NIX_CONFIG="${NIX_CONFIG:-}" NIX_REMOTE="${NIX_REMOTE:-}" \
  "$nix_bin" --extra-experimental-features 'nix-command flakes' develop .#oldGlibc -c "$root/lean-unblock-patches/build.sh" \
  "$PWD" "$root/lean-llvm-x86_64-linux-gnu.tar.zst" "$root/lean-unblocked-v4.35.0" 8
elan toolchain link lean-unblocked-v4.35.0 "$root/lean-unblocked-v4.35.0"
```

The clean environment keeps an activated Conda environment or other host build settings from supplying dependencies to CMake.

Keep a project's `lean-toolchain` file at its official value, such as `leanprover/lean4:v4.35.0`. Select the patched installation for an individual invocation with `elan run lean-unblocked-v4.35.0 lake build`. To check the official cache, run `elan run lean-unblocked-v4.35.0 lake exe cache get` in the same project before building.

### Prebuilt installations

There is currently no published release asset for this pinned revision. If you receive a Linux archive for the pinned source built with the upstream stamp, unpack it in a new directory and use `elan toolchain link` with the directory containing `bin/lean` and `bin/lake`. Check `lean --githash` through the linked toolchain against the official commit in `versions.json`. Fork CI artifacts from earlier revisions verified archive installation but used their own fork stamps.

## Validation and performance

The final patched Linux build ran all 4,220 default CTest cases. 4,218 passed. The two IPv6 loopback tests failed with the same error on the patched and official release binaries on that worker, whose loopback interface had IPv6 disabled. The original outcomes had no skips or missing cases. Five representative Mathlib modules produced the same bytes as stock across seven outputs, including the private olean files.

To reproduce the default test run from the build tree, use CTest with no selection filters:

```sh
export LEAN_GITHASH="$(cat build/release/stage1/lake-githash)"
ctest --test-dir build/release/stage1 -j4 --output-on-failure
```

In same-configuration measurements before the final name-generator isolation change, two development modules took 18.7% and 20.4% less median wall time at `-j8` (three paired runs). The median across 12 selected Mathlib modules improved 1.1% at `-j8` and 1.9% at `-j4`. These are selected-module measurements. The final isolation change was checked for artifact and test compatibility and was not retimed.

A small way to exercise the barrier is to save the following as `Barrier.lean` and run both binaries on it with `lean -j4 Barrier.lean`. Compare when the inductive command appears relative to the earlier proofs in a Lean profiler trace.

```lean
import Lean

theorem first : True := by sleep 3000; trivial
theorem second : True := by sleep 3000; trivial

inductive Tree where
  | node : List Tree → Tree

theorem later : True := by sleep 3000; trivial
```

The Lean code and patch files use the Apache License 2.0.
