# Cutting a release

`main` only changes through a pull request, squash merged, with `shellcheck`
and both `tests` jobs passing. Release tags (`v*`) cannot be moved or
deleted once pushed, so a wrong one is fixed with the next version, not by
retagging.

1. **Open a PR titled `release: X.Y.Z`** that
   - sets `VERSION='X.Y.Z'` in `claude-bgwatch`, and
   - moves the `[Unreleased]` entries in `CHANGELOG.md` under
     `## [X.Y.Z] — YYYY-MM-DD`, leaving an empty `[Unreleased]` above it.

   Merge it once the checks pass.

2. **Tag the merge commit and push the tag:**

   ```sh
   git checkout main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

3. **CI does the rest up to a draft.** On the tag, `version-matches-tag`
   fails the run if `VERSION` is not `X.Y.Z`, and `release` creates a
   **draft** release with `claude-bgwatch` and `claude-bgwatch.sha256`
   attached. The hash is also in the run's summary.

4. **Check the draft, then publish it.** Download the attached script, run it
   against your own sessions, paste that version's CHANGELOG entry as the
   notes, and publish. Publishing is what moves `releases/latest/download/`,
   which the README's install command uses, so nothing reaches anyone before
   this step.
