# CI Docker Cloud Adoption Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure every GitHub Actions workflow that builds the Cisco simulator image uses Docker Build Cloud so builds are faster, cache-aware, and identical between CI and manual triggers.

**Architecture:** The primary CI workflow (`.github/workflows/ci.yml`) keeps the existing BEAM build/test job, then introduces a dependent `docker-sim-image` job that logs in to Docker Hub (non-PR only), sets up the Docker Build Cloud builder `mlammesen/netauto-builder`, and builds/pushes the `sim_devices` Dockerfile with immutable tags (`latest` and `${{ github.sha }}`). A companion workflow (`docker-image.yml`) lets maintainers trigger the same Build Cloud pipeline via push/PR/workflow_dispatch. Both workflows reuse `${{ vars.DOCKER_USER }}` and `${{ secrets.DOCKER_PAT }}` declared in repo settings.

**Tech Stack:** GitHub Actions, Docker Build Cloud, docker/setup-buildx-action@v3, docker/build-push-action@v6, Docker Hub, NetAuto Cisco simulator Dockerfile under `sim_devices/`.

---

### Task 1: Wire Docker Build Cloud job into CI

**Files:**
- Modify: `.github/workflows/ci.yml`

**Step 1: Add docker-sim-image job**
Insert the following job definition after the existing `build` job:

```yaml
  docker-sim-image:
    name: Build Cisco sim image (Docker Cloud)
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Log in to Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ vars.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PAT }}

      - name: Set up Docker Build Cloud builder
        uses: docker/setup-buildx-action@v3
        with:
          driver: cloud
          endpoint: "mlammesen/netauto-builder"

      - name: Build and (optionally) push sim image
        uses: docker/build-push-action@v6
        with:
          context: ./sim_devices
          file: ./sim_devices/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: |
            ${{ vars.DOCKER_USER }}/netauto-sim:latest
            ${{ vars.DOCKER_USER }}/netauto-sim:${{ github.sha }}
```

**Step 2: Verify diff**
Run: `git diff .github/workflows/ci.yml`
Expected: shows the new job block only.

**Step 3: Dry-run Docker job locally**
Run (requires Docker + Docker Build Cloud credentials configured in `~/.docker/config.json`):
`act -j docker-sim-image -W .github/workflows/ci.yml -s DOCKER_PAT=$DOCKER_PAT -v DOCKER_USER=$DOCKER_USER`
Expected: `docker/build-push-action` completes without push when event defaults to pull_request.

**Step 4: Commit**
Run:
```bash
git add .github/workflows/ci.yml
git commit -m "ci: build sim image via Docker Cloud"
```

---

### Task 2: Add standalone Docker Cloud workflow

**Files:**
- Create: `.github/workflows/docker-image.yml`

**Step 1: Create workflow file**
Add the file with the following contents:

```yaml
name: Docker Cloud Image

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Log in to Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ vars.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PAT }}

      - name: Set up Docker Build Cloud
        uses: docker/setup-buildx-action@v3
        with:
          driver: cloud
          endpoint: "mlammesen/netauto-builder"

      - name: Build/push simulator image
        uses: docker/build-push-action@v6
        with:
          context: ./sim_devices
          file: ./sim_devices/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: |
            ${{ vars.DOCKER_USER }}/netauto-sim:latest
            ${{ vars.DOCKER_USER }}/netauto-sim:${{ github.sha }}
```

**Step 2: Verify diff**
Run: `git status -sb` and `git diff --stat`
Expected: shows new workflow file only.

**Step 3: Dry-run workflow**
Run: `act pull_request -j docker -W .github/workflows/docker-image.yml`
Expected: Build completes with `push` disabled because ACT simulates PR by default.

**Step 4: Commit**
Run:
```bash
git add .github/workflows/docker-image.yml
git commit -m "ci: add Docker Cloud workflow"
```

---

After both tasks, push branch and open PR summarizing Build Cloud adoption plus verification steps.
