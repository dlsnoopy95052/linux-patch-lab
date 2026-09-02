# Failure Tests

Run these intentionally after the normal workflow works.

1. Remove `jq` from a managed server and re-run `baseline.yml`.
2. Stop `nginx` or `httpd`; confirm pre-patch health validation stops patching.
3. Power off one VM; confirm Ansible reports it unreachable.
4. Power off `repo01`; confirm repository-dependent operations fail.
5. Hold/versionlock a package; confirm the policy is honored.
6. Install a kernel update; confirm reboot detection.
7. Break the `/health` endpoint after reboot; confirm rollout stops.
8. Promote a bad repository snapshot and practice reverting to the previous approved version.
