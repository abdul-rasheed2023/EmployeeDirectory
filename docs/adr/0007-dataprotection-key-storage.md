# ADR 0007: Shared Data Protection Key Storage — SSM Parameter Store over Secrets Manager

**Status:** Accepted (supersedes original Secrets Manager plan)
**Date:** 2026-09-13

## Context

ASP.NET Core's Data Protection API underlies several framework features, including
anti-CSRF ("antiforgery") token encryption/decryption. By default, each application
instance generates its own local, ephemeral cryptographic key ring. In a **single-instance**
deployment this is invisible. In this app's **multi-pod EKS deployment** (2 replicas
behind an ALB), it produces an intermittent HTTP 400: a GET request (which embeds an
antiforgery token, encrypted with the handling pod's local key) and the following POST
(routed by round-robin to a *different* pod) fail because the receiving pod cannot decrypt
a token encrypted by a key it never had.

The original infrastructure plan provisioned an AWS Secrets Manager secret
(`<prefix>-dataprotection-keyring`) as the intended shared key store, with an IAM policy
already wired to grant the app's IRSA role `secretsmanager:GetSecretValue` /
`PutSecretValue` / `DescribeSecret`.

## Decision

Use **AWS Systems Manager Parameter Store** instead, via the AWS-maintained
`Amazon.AspNetCore.DataProtection.SSM` NuGet package, rather than continuing with the
originally-planned Secrets Manager approach.

## Why the Original Plan Changed

**There is no first-party ASP.NET Core Data Protection provider for Secrets Manager.**
Microsoft's Data Protection API ships built-in support for the local file system and Azure
Blob Storage; the well-supported AWS-side equivalents are Amazon S3 (via community
packages) and Parameter Store (via an AWS-owned, actively maintained package). Using
Secrets Manager as originally planned would have required hand-writing a custom
`IXmlRepository`/`IXmlEncryptor` implementation — security-sensitive serialization code
with no first-party reference implementation to validate against, and no real-world
mileage compared to the alternatives.

## Alternatives Considered

| Option | Standard/Idiomatic | Durability | Complexity |
|---|---|---|---|
| EFS + `PersistKeysToFileSystem` | Highest (first-party Microsoft API) | High | Medium — requires provisioning EFS, a CSI driver, and a PersistentVolumeClaim |
| **SSM Parameter Store (chosen)** | Medium (AWS-owned, actively maintained package) | Medium-high | **Lowest** — one NuGet package, one method call, one scoped IAM policy statement |
| Redis (`StackExchangeRedis`) | High (first-party, most battle-tested at scale) | Highest | Highest — no Redis in this stack; would mean standing up ElastiCache and networking from scratch, reopening a caching decision already deferred in ADR 0002 |
| Custom Secrets Manager `IXmlRepository` | Lowest — no first-party or community reference implementation | Lowest — untested custom crypto-adjacent serialization code | Highest engineering effort despite reusing already-provisioned infrastructure |

Parameter Store was chosen as the best fit for this app's actual scale and existing
infrastructure: EFS and Redis are both legitimate, arguably more "textbook" choices at
larger scale, but disproportionate to provision here given no existing filesystem or cache
layer. The custom Secrets Manager repository was rejected primarily on risk grounds — key
ring serialization bugs are the kind of subtle failure (partial writes, encoding issues,
concurrent-write races) that a mature, widely-used package is far less likely to have than
code written for a single project.

## Implementation

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("EmployeeDirectory")
    .PersistKeysToAWSSystemsManager("/mno-group/dev/employee-directory/dataprotection-keys");
```

- IAM policy on the app's IRSA role scoped to `ssm:GetParameter`, `GetParameters`,
  `GetParametersByPath`, and `PutParameter`, restricted to the specific parameter path
  prefix (not a wildcard across all of Parameter Store).
- Key rotation is handled automatically by the Data Protection framework itself — default
  90-day key lifetime with a built-in activation overlap window — independent of which
  storage backend is used. No custom rotation logic was needed.

## A Second, Unrelated Bug Surfaced During Implementation

Deploying the above initially failed at startup with
`Assembly AWSSDK.SecurityToken could not be found or loaded`. IRSA authentication uses
`AssumeRoleWithWebIdentityCredentials` under the hood, which requires the AWS STS SDK
assembly at runtime — this is not pulled in transitively by the SSM Data Protection
package, and only surfaces at runtime in the specific IRSA auth path, not at compile time.
Fixed by explicitly adding the `AWSSDK.SecurityToken` NuGet package. Worth keeping as a
distinct "dependency resolution isn't always transitive, even when it logically should be"
example separate from the main ADR decision above.

## Verification

The fix was verified against the actual failure condition, not a superficial proxy for it:
a scripted test performed a real GET (loading the Create form and its antiforgery token)
immediately followed by a real POST using that token, repeated 15 times against the
load-balanced URL to force genuine round-robin distribution across both pods.

- **Before the fix:** intermittent HTTP 400s.
- **After the fix:** 15/15 requests returned HTTP 302 (successful creation + redirect),
  with `aws ssm get-parameters-by-path` independently confirming a real, encrypted
  (`SecureString`) key had been written and shared.

An earlier test attempt used only GET requests and returned 15/15 200s — which looked like
a pass but never exercised the actual bug (the failure only occurs on the GET→POST
handoff). Catching that the test itself was invalid, before declaring the fix verified, is
worth keeping as a specific example of testing rigor.

## Consequences

- The original Secrets Manager secret and its associated Terraform resource, output, and
  pod environment variable (`DataProtection__SecretArn`) were removed entirely rather than
  left as dead infrastructure — confirmed via `terraform plan` showing exactly one `destroy`
  (the unused secret) and one in-place update (the env var removal), with no unrelated
  changes.
- Anyone extending this app to a second environment (staging/prod) needs its own distinct
  parameter path prefix — the path is currently environment-specific
  (`/mno-group/dev/employee-directory/...`), not parameterized further than that.
