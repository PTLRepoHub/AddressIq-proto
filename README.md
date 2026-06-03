# AddressIQ Proto

The **single source of truth** for the AddressIQ wire contract. Every client SDK
(web, React Native, Flutter, iOS, Android) and the backend are generated from /
aligned to the messages defined here.

```
addressiq/v1/
├── common.proto         # identity primitives, GeoPoint, ErrorCode, enums
├── verification.proto   # Verification, status/type/review enums
├── telemetry.proto      # TransitEvent envelope, SecurityEnvelope (Phase 3 §5)
└── sdk.proto            # SDK lifecycle / permission state
```

Package: `addressiq.v1` · BSR module: **`buf.build/addressiq/addressiq`**

## Consuming the contract

SDKs generate language bindings with their own `buf.gen.yaml`. Two equivalent
input sources are supported:

**Today — directly from this git repo** (no account required):

```yaml
# buf.gen.yaml in an SDK repo
version: v2
inputs:
  - git_repo: https://github.com/PTLRepoHub/AddressIq-proto.git
    branch: main
plugins:
  - remote: buf.build/community/stephenh-ts-proto:v1.181.2
    out: src/proto
```

**Once BSR is set up** — pin a published version:

```yaml
inputs:
  - module: buf.build/addressiq/addressiq
```

Run `buf generate` in the SDK repo to (re)produce bindings.

## Releasing to the Buf Schema Registry

Publishing is automated by [`bufbuild/buf-action`](https://github.com/bufbuild/buf-action)
in [`.github/workflows/ci.yml`](.github/workflows/ci.yml). To enable it:

1. Create the org + module on [buf.build](https://buf.build) so that
   `buf.build/addressiq/addressiq` exists (change the `name:` in `buf.yaml` if
   you use a different org).
2. Generate a token (Settings → Tokens) and add it to this repo as the
   **`BUF_TOKEN`** secret (Settings → Secrets and variables → Actions).
3. Push to `main` to publish a commit, or push a `vX.Y.Z` tag to publish a
   labeled release:

   ```sh
   git tag v1.0.0 && git push origin v1.0.0
   ```

Until `BUF_TOKEN` exists the push step is skipped — CI still lints, builds, and
checks for breaking changes.

## Local development

```sh
make lint      # buf lint
make format    # buf format -w
make build     # buf build
make breaking  # breaking-change check against origin/main
```

Requires [`buf`](https://buf.build/docs/installation) (`brew install bufbuild/buf/buf`).
