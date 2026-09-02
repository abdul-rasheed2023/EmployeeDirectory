# ECR Module: Modifications to Your EXISTING Files

These are the ONLY changes needed to wire the new ECR module into your existing Terraform project.

---

## File 1: `environments/dev/main.tf`

### What to do:
Add this block AFTER the `eks` module and BEFORE the `notifications` module.

### Where:
Look for this in your file (around line 80):
```hcl
module "eks" {
  source = "../../modules/eks"
  ...
}

module "notifications" {
```

### Add this BETWEEN them:

```hcl
module "ecr" {
  source = "../../modules/ecr"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  eks_node_role_arn  = module.eks.node_role_arn
}
```

**Total lines added:** 7 lines

---

## File 2: `environments/dev/outputs.tf`

### What to do:
Append these THREE new outputs at the end of the file.

### Where:
Open `environments/dev/outputs.tf` and go to the bottom (after the last output block).

### Add this:

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

**Total lines added:** 11 lines

---

## File 3: `modules/eks/outputs.tf` — CHECK IF THIS EXISTS

### What to do:
Check if `node_role_arn` is already in the outputs. If NOT, add it.

### How to check:
Open `modules/eks/outputs.tf` and search for `node_role_arn`.

### If it's MISSING, add this:

```hcl
output "node_role_arn" {
  description = "ARN of the EKS node IAM role — used by ECR module for image pull permissions"
  value       = aws_iam_role.eks_node.arn
}
```

**Total lines added (if missing):** 4 lines

### If it's ALREADY there:
✅ Nothing to do — move on.

---

## Summary of Changes

| File | Action | Lines | Impact |
|---|---|---|---|
| `environments/dev/main.tf` | Add ECR module block | +7 | Instantiates ECR repo |
| `environments/dev/outputs.tf` | Add 3 ECR outputs | +11 | Exposes repo URL for CI/CD |
| `modules/eks/outputs.tf` | Add node_role_arn output (if missing) | +4 | Provides trust relationship |
| `modules/ecr/` (new folder) | Copy 3 new files | — | Module implementation |

**Total changes to existing files:** ~18 lines across 2-3 files

---

## What NOT to change:

❌ Don't modify existing module blocks (network, security, data, iam, compute, eks, notifications)  
❌ Don't change any variable names or defaults  
❌ Don't touch provider.tf, versions.tf, or variables.tf (unless specifically noted)

---

## Verification After Changes

After making these modifications, test by running:

```bash
# This won't apply anything, just checks syntax
cd environments/dev
terraform init
terraform validate

# If no errors, you're good!
# Then run plan to see what would be created (requires AWS creds):
terraform plan -var-file="dev.tfvars"
```

You should see in the plan output:
```
+ aws_ecr_repository.employee_directory
+ aws_ecr_lifecycle_policy.employee_directory
+ aws_ecr_repository_policy.allow_eks_nodes
```

---

## Next Steps

Once you've made these modifications:

1. ✅ Create `modules/ecr/` folder
2. ✅ Copy the 3 ECR files (ecr_main.tf, ecr_variables.tf, ecr_outputs.tf) into that folder
3. ✅ Modify `environments/dev/main.tf` (add ECR module block)
4. ✅ Modify `environments/dev/outputs.tf` (add ECR outputs)
5. ✅ Check `modules/eks/outputs.tf` for node_role_arn (add if missing)
6. ✅ Run `terraform validate` to confirm syntax is correct

Then reply **"Task 1 complete"** and we move to **Task 2: Write the Compute Platform Decision ADR**.
