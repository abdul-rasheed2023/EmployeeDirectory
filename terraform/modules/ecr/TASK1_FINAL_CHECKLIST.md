# Task 1 Final Checklist: ECR Module Setup

## ✅ GOOD NEWS

Your `modules/eks/outputs.tf` **ALREADY HAS** the `node_role_arn` output (lines 26-28):

```hcl
output "node_role_arn" {
  value = aws_iam_role.eks_node.arn
}
```

**No changes needed to that file.** ✅

---

## What You Need to Do (3 Steps)

### Step 1: Create the ECR module folder
```bash
mkdir -p modules/ecr
```

### Step 2: Copy these 3 new files into `modules/ecr/`
- `ecr_main.tf` → rename to `main.tf`
- `ecr_variables.tf` → rename to `variables.tf`
- `ecr_outputs.tf` → rename to `outputs.tf`

**Files are in `/mnt/user-data/outputs/` ready for you to download.**

### Step 3: Modify 2 existing files

#### File A: `environments/dev/main.tf`

**Find this section (around line 80):**
```hcl
module "eks" {
  source = "../../modules/eks"
  ...
}

module "notifications" {
```

**Insert this BETWEEN the two blocks:**
```hcl
module "ecr" {
  source = "../../modules/ecr"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  eks_node_role_arn  = module.eks.node_role_arn
}
```

---

#### File B: `environments/dev/outputs.tf`

**Go to the END of the file and append:**
```hcl
output "ecr_repository_url" {
  description = "ECR repository URL — use this in CI/CD pipelines to push images"
  value       = module.ecr.repository_url
}

output "ecr_registry_id" {
  description = "AWS account ID for the ECR registry"
  value       = module.ecr.registry_id
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}
```

---

## Summary

| Item | New/Modified? | Status |
|---|---|---|
| Create `modules/ecr/` folder | NEW | ✅ Files ready in outputs |
| Copy `ecr_main.tf` | NEW | ✅ Download from outputs |
| Copy `ecr_variables.tf` | NEW | ✅ Download from outputs |
| Copy `ecr_outputs.tf` | NEW | ✅ Download from outputs |
| Modify `environments/dev/main.tf` | +7 lines | ⏳ You do this |
| Modify `environments/dev/outputs.tf` | +11 lines | ⏳ You do this |
| Modify `modules/eks/outputs.tf` | NO CHANGE | ✅ Already has node_role_arn |

---

## Verification After Changes

After completing all 3 steps, run this command in your project root:

```bash
cd environments/dev
terraform validate
```

✅ If no errors, you're good!  
❌ If errors, paste them and I'll help debug.

---

## When You're Done

Reply with:
- ✅ "Task 1 complete — ECR module wired"
- Or paste any errors from `terraform validate` if something doesn't work

Then we move to **Task 2: Write the Compute Platform Decision ADR** (explaining EKS vs EC2).
