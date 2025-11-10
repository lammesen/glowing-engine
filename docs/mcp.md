# CircleCI MCP Integration

The “CircleCI MCP Server” (from the Docker MCP Toolkit) gives AI agents read-only access to recent builds, logs, and pipeline metadata so they can troubleshoot CI without re-running jobs manually.

## What It Can Do

- **Validate configs** – `circleci.validate_config` parses `.circleci/config.yml` and reports schema errors before you push.
- **Inspect jobs** – `circleci.get_pipeline` or `circleci.get_workflow_jobs` answer “What failed on my last build?” including timestamps, rerun URLs, and summarized logs.
- **Find flaky tests** – `circleci.list_failed_tests` surfaces repeated failures across builds so you know which suites to stabilize.
- **Stream artifacts/logs** – `circleci.get_artifact` fetches `test_results/*.xml` or coverage JSON for deeper analysis.

## Example Prompts

1. “Validate my CircleCI config.” → MCP runs `circleci validate` and returns structured errors with line numbers.
2. “List flaky tests in my current project.” → Agent calls `circleci.list_failed_tests` (filtered to `net_auto` job names) and summarizes repeated offenders with job IDs.
3. “Get logs from the last failed job.” → Agent retrieves `docker_build_push` (or whichever job failed) log chunks so you can spot credential issues instantly.

## Client Configuration Snippet

Add this block to your MCP-enabled client (Claude Desktop, Cursor, Windsurf, etc.):

```json
{
  "mcpServers": {
    "circleci": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-e", "CIRCLE_TOKEN=$CIRCLE_TOKEN",
        "ghcr.io/mcp-tools/circleci-mcp:latest"
      ]
    }
  }
}
```

Requirements:

1. Install the Docker MCP Toolkit (`brew install --cask docker-mcp-toolkit` or follow the project README).
2. Export `CIRCLE_TOKEN` with read permissions for the `lammesen/glowing-engine` project.
3. Start your MCP-aware IDE/editor; it will spawn the CircleCI server automatically and expose the methods listed above.

## Security Notes

- The MCP server only uses the CircleCI API token from your local environment; never commit tokens to git.
- Keep CircleCI contexts (e.g., `netauto-ci`) scoped to jobs that actually need secrets—MCP can read job metadata but not secret values.
- For GHCR pushes, rotate `GHCR_PAT` regularly and store it solely in the CircleCI context, not the MCP client config.

Refer back to `docs/ci.md` for pipeline/high-level documentation; use this file when you need AI assistance debugging or auditing CI runs.
