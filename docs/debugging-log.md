# Debugging log — real issues encountered and resolved

This log tracks real problems hit during development, how they were diagnosed, and how they were fixed. Kept as both a personal reference and interview preparation material — each entry maps to a "tell me about a time..." style question.

---

## 1. CI failed on hardcoded local file path (Terraform)

**What happened:** `aws_key_pair` resource used `file("~/.ssh/idp-platform-key.pub")` to read the SSH public key. Worked perfectly locally, failed immediately in GitHub Actions CI with "no file exists at ~/.ssh/idp-platform-key.pub".

**Root cause:** CI runners are separate, ephemeral cloud machines with no access to my laptop's filesystem. The `~` path only resolved on my local machine.

**Fix:** Replaced the hardcoded file read with a Terraform `variable` (`var.ssh_public_key`). Locally, the value comes from a git-ignored `terraform.tfvars` file. In CI, it's passed via a GitHub Secret using a `-var` flag on the command line.

**Interview angle:** "Tell me about a time your code worked locally but failed in CI." Real example of environment-specific assumptions breaking portability, and the correct general pattern (decouple inputs via variables) rather than a one-off patch.

---

## 2. CI job hung for 8+ minutes waiting for interactive input

**What happened:** After fixing issue #1, `terraform apply -auto-approve` in CI hung indefinitely instead of failing or completing. Logs showed it was waiting for a value for `var.ssh_public_key`.

**Root cause:** A `sed` command intended to add the `-var` flag to both the `plan` and `apply` steps only successfully matched the `plan` line, due to inconsistent whitespace in the target line breaking the pattern match. The `apply` step was missing the flag entirely, so Terraform fell back to prompting for the variable interactively, which CI can never answer, causing an indefinite hang.

**Fix:** Manually verified both lines with `grep`, found the missing flag, and fixed it directly by line number using `sed`, then re-verified with `grep` before committing.

**Interview angle:** Good example of why automated find-and-replace across config files needs verification, not blind trust, and why reading actual log output rather than assuming a fix worked is critical.

---

## 3. Stale DynamoDB state lock after a cancelled CI run

**What happened:** After cancelling the hung run from issue #2, the next CI run failed immediately with `Error acquiring the state lock`, a `ConditionalCheckFailedException` from DynamoDB.

**Root cause:** Terraform's state locking, via the DynamoDB table set up in Ticket 6, writes a lock record before any apply. Cancelling a run mid-flight doesn't guarantee that lock gets released, and it was still present, blocking any new apply from proceeding.

**Fix:** Used `terraform force-unlock <lock-id>` (lock ID was included directly in the error output) to manually clear the stale lock, then verified with `terraform plan` that operations resumed normally before re-triggering CI.

**Interview angle:** Direct, concrete explanation of why state locking exists and what happens when it's actually triggered. Most candidates can explain the concept, fewer have actually hit and resolved a real lock conflict.

---

## 4. GitHub contribution graph showed missing days despite real commits

**What happened:** GitHub's contribution graph showed 0 contributions on two days where real work and commits had genuinely happened.

**Root cause:** Local git config was set to an email address that was never verified on my GitHub account. GitHub only counts commits toward the contribution graph when the author email matches a verified account email.

**Fix:** Updated `git config --global user.email` to the correct verified address for future commits, then used `git filter-branch` to rewrite the author/committer email on all historical commits, and force-pushed the corrected history.

**Interview angle:** Practical git history management, knowing when rewriting history is safe (solo repo, no collaborators yet) versus dangerous (shared repos where others have already pulled).

---

## 5. YAML indentation errors from manual editing (recurring)

**What happened:** Multiple instances across several tickets where manually editing `.yml`/`.tf` files in nano introduced subtle indentation drift, since nano's auto-indent copies previous line indentation, or dropped/duplicated content, causing parser errors that were hard to catch by visually reading pasted terminal output.

**Fix / lesson:** Switched to two more reliable habits: (1) writing files via heredoc (`cat > file << 'EOF'`) for guaranteed exact content with no editor-introduced drift, and (2) always verifying with the actual parser (`python3 -c "import yaml; yaml.safe_load(...)"` or `terraform validate`) instead of eyeballing pasted text, which can render inconsistently anyway.

**Interview angle:** Demonstrates a real engineering habit — trust the tool's validation, not visual inspection, especially for whitespace-sensitive formats.

## 6. GitHub Actions 403 error despite correct workflow-level permissions

**What happened:** A CI step using `actions/github-script` to post a commit comment failed with `403: Resource not accessible by integration`, even after adding an explicit `permissions: contents: write` block to the job in the workflow YAML.

**Root cause:** GitHub Actions has two layers of permission control — the workflow file's `permissions:` block, and a repository-wide default under Settings > Actions > General > "Workflow permissions." The repo was set to "Read repository contents permission" (read-only) by default, which acted as a hard ceiling, overriding the more permissive setting requested in the workflow YAML itself.

**Fix:** Changed the repository-wide setting to "Read and write permissions" under Settings > Actions > General.

**Interview angle:** A good example of permissions systems having multiple layers that aren't visible from the code alone. Debugging required reading the actual API response headers (`x-accepted-github-permissions`) rather than just assuming the YAML fix would work, and recognizing that a 403 with seemingly-correct code often points to an external policy, not a syntax issue.
