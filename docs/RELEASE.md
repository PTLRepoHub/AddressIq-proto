# AddressIQ Proto — Release Guide

This repo holds the AddressIQ wire contract (`.proto` files under `addressiq/`) and
publishes it as a single Buf module to the Buf Schema Registry (BSR).

- **BSR module:** `buf.build/addressiq/addressiq` (declared in `buf.yaml:3`).
- **Role:** this is the *contract hub*. All consumer SDKs
  (`addressiq-web`, `addressiq-react-native`, `addressiq-android`, `addressiq-ios`,
  `addressiq-flutter`) generate their bindings from a pinned version of this module.
  The proto version is the contract version; each SDK versions independently and
  declares which proto it implements via a `.proto-version` file.
- The module currently defines **messages and enums only — no `service`/`rpc`**
  (see `RELEASE-ENGINEERING.md:298`).

## Release flow

1. **Conventional commits** land on `main`.
2. **release-please** (`.github/workflows/release-please.yml`) runs on every push to
   `main` and maintains a `chore: release X.Y.Z` PR
   (`release-please-config.json:5`). It uses the `simple` release type
   (`release-please-config.json:8`), writes `CHANGELOG.md`, bumps the version, and on
   merge pushes tag `vX.Y.Z`.
   - The action authenticates with a **GitHub App token**, not the default
     `GITHUB_TOKEN` (`release-please.yml:29-34`). This is deliberate: GitHub does not
     fire downstream workflows for events created by `GITHUB_TOKEN`, so an
     App-authored tag/release is required to trigger the publish and fanout steps
     (`release-please.yml:6-9`).
3. **BSR push** — the actual trigger is **`ci.yml`, not a separate `release.yml`**
   (there is no `release.yml` in this repo; the comment at `release-please.yml:8`
   referencing one is stale). `ci.yml` runs on pushes to `main` and on `v*` tags
   (`ci.yml:9-11`) and invokes `bufbuild/buf-action`. Its `push` input is gated on
   `secrets.BUF_TOKEN != ''` (`ci.yml:33`), so the module is published to the BSR
   only when a `BUF_TOKEN` is configured; otherwise the push step is skipped and CI
   still passes lint/format/build/breaking. In short: the release tag push (and any
   push to `main`) is what drives the BSR publish, keyed off `BUF_TOKEN`.
4. **Fanout** — `.github/workflows/fanout.yml` fires on `release: published`
   (`fanout.yml:23-25`), with a `workflow_dispatch` fallback that takes a
   `proto_tag` input (`fanout.yml:26-35`). For each consumer SDK (a matrix at
   `fanout.yml:47-58`) it:
   1. mints an App token **narrowed to that one repo** (`fanout.yml:97-104`),
   2. checks out the SDK's `main`,
   3. repins `buf.gen.yaml` from `branch: main` (or an older `tag:`) to the new
      `tag: vX.Y.Z` via `sed` (`fanout.yml:116-133`),
   4. writes `.proto-version` and runs that repo's `buf generate`
      (`fanout.yml:135-136`; flutter uses `--include-imports --include-wkt`,
      `fanout.yml:57-58`),
   5. opens a `proto-sync`-labelled PR if anything changed (`fanout.yml:149-181`).

   The **proto→SDK version linkage is carried by the regen PR's commit type**
   (`fanout.yml:9-12`, `156-168`): a proto MAJOR bump lands as `feat(proto)!:`
   (majors the SDK), anything else lands as `feat(proto):` (minors it). "MAJOR"
   is decided by comparing the new tag's major against the previous release tag
   (`fanout.yml:75-95`); the first release is never breaking.

## Required secrets

| Secret | Used by | Purpose / source |
| --- | --- | --- |
| `BUF_TOKEN` | `ci.yml:29,33` | Authenticates the BSR push. Provision via a token on buf.build for org/module `addressiq/addressiq` (`RELEASE-ENGINEERING.md:143`). If unset, the push is a no-op. |
| `ADDRESSIQ_BOT_APP_ID` | `release-please.yml:33`, `fanout.yml:101` | GitHub App ID. Enables App-authored tag pushes (to trigger downstream workflows) and cross-repo writes into consumer SDKs. |
| `ADDRESSIQ_BOT_PRIVATE_KEY` | `release-please.yml:34`, `fanout.yml:102` | Private key for the same GitHub App. |

Both workflows use the **same GitHub App** (`fanout.yml:14-15`).

## Versioning rules (release-please)

- Release type `simple` (`release-please-config.json:8`).
- `bump-minor-pre-major: true` (`release-please-config.json:9`) — while pre-1.0,
  breaking changes bump the *minor*, not the major.
- Tags are plain `vX.Y.Z`: `include-component-in-tag: false`,
  `tag-separator: "-"` (`release-please-config.json:3-4`).
- Current version is seeded at **`0.1.0`** in `.release-please-manifest.json:2`.
  This is intentionally not `v1.0.0`: `v1.0.0` would freeze the contract and make
  `buf breaking` a hard gate while the contract is still moving
  (`RELEASE-ENGINEERING.md:297`).

## Known concern: consumer `buf.gen.yaml` pin `branch: main`

All five SDKs currently pin their `buf.gen.yaml` to `branch: main`
(`RELEASE-ENGINEERING.md:32`). A merge to proto therefore silently changes
generated code in every SDK, and **builds are not reproducible**. SDKs should pin
to a proto **tag/version** instead. This is by design pre-first-release: pinning to a
tag that does not yet exist would break `proto-sync.yml` immediately
(`RELEASE-ENGINEERING.md:202`); the **first fanout run does the repinning**
(`branch: main` → `tag: vX.Y.Z`, `fanout.yml:123-127`,
`RELEASE-ENGINEERING.md:200`).

## Local validation

`buf.yaml` configures lint (`STANDARD`, excluding `ENUM_VALUE_PREFIX`) and breaking
(`FILE`) — `buf.yaml:5-16`.

```sh
buf lint
buf breaking --against 'https://github.com/addressiq/AddressIq-proto.git#branch=main'
```

CI runs the same checks via `bufbuild/buf-action`, comparing breaking changes against
the `main` branch (`ci.yml:34-35`). See also the repo `Makefile` for shortcuts.
