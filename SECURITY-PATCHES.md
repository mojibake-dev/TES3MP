# Security patches for TES3MP 0.8.1

This fork exists to publish fixes for six security defects in TES3MP 0.8.1 and the CrabNet library
it links, because the upstream repository will not accept them.

**If you run a TES3MP 0.8.1 server, it is remotely exploitable and upstream is unpatched.** The
headline defect gives remote code execution as the server user with no account, and on the shipped
default configuration, which sets no `password`, with no secret of any kind. Patch and rebuild, or
accept that anyone who can reach your game port can run commands on that host.

## The patches

| Fix | Defect | CVE | Severity |
|---|---|---|---|
| [#1](../../pull/1) | Unbounded signed wire index into `Item equipmentItems[19]`, remote code execution | CVE-2026-79511 | 9.8 |
| [#3](../../pull/3) | Unbounded wire-driven counts reaching `resize()`, one-packet denial of service | CVE-2026-79510 | 7.5 |
| [#2](../../pull/2) | `PacketActorEquipment` relays uninitialized memory to unauthenticated peers | CVE-2026-79509 | 5.3 |
| [#4](../../pull/4) | Optional build hardening. Defence in depth, not a fix for any of the above | | |

Each pull request explains the defect, its reachability, what the change does, what it deliberately
does not do, and how it was verified. Issues [#5](../../issues/5), [#6](../../issues/6) and
[#7](../../issues/7) describe the defects separately from the fixes.

Three further defects are in CrabNet, below the game's own password gate, so no server configuration
mitigates them: CVE-2026-79506, CVE-2026-79507 and CVE-2026-79508. They are reported at
[TES3MP/CrabNet](https://github.com/TES3MP/CrabNet/issues) as issues 20, 21 and 23, which are still
open. The same defects exist in SLikeNet, another RakNet descendant, as CVE-2026-88291 and
CVE-2026-88292.

## Applying them

Cherry-pick, or merge the branches:

```sh
git remote add patches https://github.com/mojibake-dev/TES3MP.git
git fetch patches
git merge patches/fix/equipment-index-bounds
git merge patches/fix/uninitialized-item-scalars
git merge patches/fix/bound-wire-counts
```

All three are wire-compatible: a server built from them interoperates with stock clients. Nothing
here changes the protocol, deliberately, so that an operator can patch a server without requiring
every player to update. The tidier version of the first fix would narrow a container type and break
that, which is why it is not done here.

Build hardening is opt-in, `-DOPENMW_HARDENING=ON`.

Note that stock 0.8.1 does not build on a current toolchain. `components/misc/utf8stream.hpp` needs
`<cstdint>`, fixed upstream in `7921f71a7`, and
`apps/openmw-mp/Script/Types.hpp` selects a `constexpr` constructor per compiler where neither
branch satisfies both GCC 13 and Clang 18. Neither is addressed here; both are build problems rather
than security ones.

## Why this is not upstream

The six defects were reported to upstream on 2026-08-19 as eight issues, written to describe each
defect and its fix without publishing an exploitation chain.

Three of those issues, on `TES3MP/TES3MP`, were deleted without reply. They return HTTP 410. The
remaining five, on `TES3MP/CrabNet` and `SLikeSoft/SLikeNet`, are still open and unanswered.

The reporting account is now blocked by the TES3MP organisation. Opening a pull request there
returns `GraphQL: User is blocked (createPullRequest)`, and forking any repository the organisation
owns returns HTTP 403, while the same account forks other repositories without difficulty and the
repository itself reports `pull_request_creation_policy=all`.

So these patches cannot be offered upstream. They are published here instead, where they cannot be
deleted, so that operators and the maintainers of active forks have something to apply. The last
push to `TES3MP/TES3MP` was May 2024.

## Verification

The fixes were tested against the defects rather than only reviewed. Two server binaries built from
the same tree with the same compiler and flags, differing only by these patches:

- The out-of-bounds read stops at its first step, where it previously leaked a heap pointer and the
  player object base pre-authentication.
- An out-of-range index stopped reaching the `OnPlayerEquipment` Lua callback, from twenty times in
  one run to zero. This part matters: a bounds check alone does not fix the first defect, because
  the rejected index is still in the change list and stock CoreScripts feeds it back through
  `EquipItem`, which indexes the same array unbounded.
- Under AddressSanitizer and UndefinedBehaviorSanitizer, the unpatched build reports
  `index 1094795585 out of bounds for type 'Item[19]'` and faults while writing the out-of-range
  item; the patched build exits silently.
- One packet requesting a 17 GB allocation is rejected rather than terminating the server.
- Well-formed equipment packets on both code paths are accepted identically before and after, so
  normal play is unaffected.

A full gameplay regression against a real client was not performed and is the one thing an adopter
should run before trusting this in production.

## Contact

Eli Samara, <eli.samara@mojibake.dev>. Findings, corrections and provenance at
[mojibake.dev](https://mojibake.dev).
