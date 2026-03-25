---
name: request-review
description: Request a Codex Connector review on a PR by posting @codex review as a comment, then poll until the review arrives.
---

# Request Review

After creating or updating a PR, request an automated code review from the Codex Connector GitHub App.

## Steps

1. Post the review request comment on the PR:
   ```bash
   gh pr comment <PR_NUMBER> --repo Factory-Twelve/<repo> --body "@codex review"
   ```

2. Poll for the review to arrive (check every 30 seconds, up to 5 minutes):
   ```bash
   gh api repos/Factory-Twelve/<repo>/pulls/<PR_NUMBER>/reviews \
     --jq '[.[] | select(.user.login | test("codex|openai"; "i"))] | length'
   ```
   - If count > 0, the review has arrived.
   - Read the review body and state.

3. If the review requests changes:
   - Address each point raised.
   - Push fixes.
   - Request a fresh review (`@codex review` again).
   - Repeat until the review passes or is COMMENTED without blocking issues.

4. If the review approves or comments without blocking issues:
   - Note the review result in the workpad.
   - Proceed to Human Review.

## Notes

- Do NOT move to Human Review until the Codex review has been received and addressed.
- If the Codex Connector doesn't respond within 5 minutes, note the timeout in the workpad and proceed — don't block indefinitely.
