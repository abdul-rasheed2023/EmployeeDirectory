# Image Promotion Pattern

## Principle

**One image, built once, promoted through environments by retagging —
never rebuilt per environment.**

The image that gets tested, scanned by Trivy, and approved is the exact
same set of bytes that runs in every environment it's promoted to. Only
the tag changes. Rebuilding per environment would mean dev, staging, and
production are running artifacts that were never actually the thing that
passed CI — defeating the entire point of the pipeline in Days 14–20.

## What "promotion" means here

The build in `ci.yml` (Day 17) tags the image by commit SHA:
```
employee-directory:<commit-sha>
```
That SHA-tagged image is what gets scanned (Day 18) and is the sole
build artifact for that commit, for the life of that commit.

"Promoting" an image to an environment means adding a second, mutable
tag pointing at that same image digest — e.g. `staging`, `production` —
without triggering a new `docker build`. The underlying image content is
byte-identical across every environment it's promoted to.

## Why this matters (not just process for its own sake)

- Guarantees the image running in production passed the exact same
  Trivy scan and test suite as what was validated earlier — no drift
  between "what we tested" and "what we shipped."
- Makes rollback trivial: rolling back is repointing a tag to a
  previous SHA, not rebuilding an old commit and hoping the build
  environment hasn't changed since.
- Removes an entire class of "worked in staging, broke in prod" bugs
  caused by non-deterministic builds (dependency resolution drift,
  base image updates between builds, etc.).

## Mechanics (once ECR exists — Day 19)

```bash
# Pull the already-built, already-scanned image by its immutable SHA tag
docker pull <account-id>.dkr.ecr.<region>.amazonaws.com/employee-directory:<commit-sha>

# Retag it for the target environment — no rebuild
docker tag <account-id>.dkr.ecr.<region>.amazonaws.com/employee-directory:<commit-sha> \
           <account-id>.dkr.ecr.<region>.amazonaws.com/employee-directory:production

# Push only the new tag — the underlying layers already exist in the registry,
# so this is a fast, layer-reuse push, not a full re-upload
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/employee-directory:production
```

The `promote.sh` script below wraps this so it's a single command instead
of three, and fails loudly if the source SHA tag doesn't exist (i.e.
someone tries to promote a commit that was never actually built/scanned).

## What this is NOT

- Not a rebuild with different `--build-arg` values per environment —
  any environment-specific behavior belongs in runtime config (Day 23's
  secrets/config boundary), not baked into the image at build time.
- Not blocked on having multiple real environments today — this pattern
  is documented now so it's the default habit once ECR and multiple
  environments exist, rather than something retrofitted after bad habits
  form.

## Status

Documented now (Day 24); the script below is ready to use once ECR
exists (Day 19, deferred to next month). Until then, this remains the
committed pattern for how promotion *will* work, not something
executable against a real registry yet.
