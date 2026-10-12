# Committee Hub JMeter Load Testing Suite

Automated performance and load testing suite for the **Committee Hub** application.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration & Usage](#configuration--usage)
  - [Using the Runner Script (`run-test.sh`)](#using-the-runner-script-run-testsh)
  - [Environment Variables](#environment-variables)
  - [Examples](#examples)
- [Test Plan Architecture](#test-plan-architecture)
  - [Single-Login Session Sharing Pattern](#single-login-session-sharing-pattern)
  - [Thread Groups](#thread-groups)
- [Direct JMeter CLI Usage](#direct-jmeter-cli-usage)
- [Results and HTML Reports](#results-and-html-reports)

---

## Overview

This repository provides load testing scenarios for the Committee Hub backend, focusing on high-volume user actions:
- **Submissions Creation** (`/submissions/create`)
- **Meetings Creation** (`/meetings/create`)
- **Minutes of Meeting (MoM) Report Downloads**

Tests are configured dynamically using JMeter properties (`__P(...)`), allowing execution across local, staging, or production-like environments without editing test files.

---

## Prerequisites

1. **Apache JMeter 5.5+** (tested with JMeter 5.6.3):
   Ensure `jmeter` is installed and available in your system `$PATH`:
   ```bash
   jmeter -v
   ```
2. **Active VPN Connection:**
   The test environment (`*.azurewebsites.net` / `stg.committeehub.gov.ae`) enforces IP access restrictions. Ensure your organization's VPN is active before launching tests against Azure-hosted targets.

---

## Quick Start

Execute a test run with default settings (against the default staging host with default credentials):

```bash
./run-test.sh
```

By default, this runs:
- **Host:** `app-chub-test-weu-01-fad6buf3ejgffnh9.westeurope-01.azurewebsites.net`
- **User:** `fatima.alzubaidi@dge.gov.ae`
- **Workload:** 500 threads per thread group, ramped up over 500 seconds.

---

## Configuration & Usage

### Using the Runner Script (`run-test.sh`)

`run-test.sh` is an executable wrapper that:
- Automatically strips `https://` / `http://` prefixes and port suffixes from the host URL.
- Automatically URL-encodes `@` signs in usernames (`fatima.alzubaidi%40dge.gov.ae`) for form-urlencoded bodies.
- Generates timestamped test artifacts and full HTML performance dashboard reports.

#### Positional Arguments

```bash
./run-test.sh [HOST] [USERNAME] [PASSWORD]
```

### Environment Variables

You can configure any parameter via environment variables:

| Variable | Description | Default Value |
| :--- | :--- | :--- |
| `TEST_HOST` | Target domain or URL (e.g. `stg.committeehub.gov.ae`) | `app-chub-test-weu-01-fad6buf3ejgffnh9.westeurope-01.azurewebsites.net` |
| `TEST_USER` | Login email address | `fatima.alzubaidi@dge.gov.ae` |
| `TEST_PASS` | Login password | `Testing123!` |
| `THREADS` | Number of concurrent threads per active thread group | `500` |
| `RAMPUP` | Thread ramp-up time in seconds | `500` |
| `TEST_PORT` | Port override (optional, defaults to 443 for https) | `443` |
| `TEST_PROTOCOL` | Protocol override (`https` or `http`) | `https` |
| `REPORT_DIR` | Custom output directory for the HTML report | `${OUTPUT_DIR}/report` |

*(Note: The variable `TEST_USER` is used instead of `USERNAME` to prevent conflicts with the standard Linux `$USERNAME` environment variable).*

### Examples

#### Smoke Test (2 threads, 1s ramp-up)
```bash
THREADS=2 RAMPUP=1 ./run-test.sh
```

#### Medium Load (50 concurrent threads per group, 15s ramp-up)
```bash
THREADS=50 RAMPUP=15 ./run-test.sh
```

#### High Load against Custom Staging Domain
```bash
THREADS=100 RAMPUP=30 ./run-test.sh stg.committeehub.gov.ae user@dge.gov.ae SecretPass123!
```

#### Local Mock Server (HTTP on custom port)
```bash
THREADS=10 RAMPUP=1 ./run-test.sh http://127.0.0.1:9090 test@test.com Pass123!
```

---

## Test Plan Architecture

### Single-Login Session Sharing Pattern

**Why this exists:**
When launching hundreds of concurrent threads with a single test account, having each thread log in concurrently triggers backend rate-limiting (`302 Moved to /login?passwordLogin=true&rateLimited=true`), causing subsequent requests to fail with `401 Unauthorized`.

**How it works:**
1. **`setUp Thread Group - Single Login`:** Executes **exactly once** before any workload thread groups start.
   - Issues `GET /login?passwordLogin=true` to extract the CSRF antiforgery token (`__RequestVerificationToken`).
   - Issues `POST /login?passwordLogin=true` to authenticate.
   - An attached **JSR223 PostProcessor (`Save Cookies to Properties`)** extracts the authenticated session cookies (`.AspNetCore.Cookies`, `ARRAffinity`, etc.) from the thread's CookieManager and saves them into JMeter's global `props`.
   - If login fails, `stoptest` immediately aborts the test run to avoid unauthenticated spamming.
2. **Global Cookie Manager:** Configured with `clearEachIteration=false` so cookies persist across thread loops.
3. **Workload Thread Groups:** Each active thread group includes an **`Apply Shared Cookies` JSR223 PreProcessor** that injects the shared cookies directly into each thread's local `CookieManager`. All threads immediately begin issuing authenticated requests without touching the login endpoints.

### Thread Groups

| Thread Group | Enabled by Default | Purpose |
| :--- | :--- | :--- |
| **`setUp Thread Group`** | **Yes** | 1 thread; logs in once and exports session cookies. |
| **`TG1 - Create Submission`** | **Yes** | Sends `POST /submissions/create` with payload `{}`. |
| **`TG2 - Create Meeting`** | **Yes** | Sends `POST /meetings/create` with payload `{}`. |
| **`TG3 - Download MoM Report`** | No | Sends `GET /meetings/{id}/mom-report/{id}` to measure large report download times. |

To enable or disable specific thread groups, open `chub-test.jmx` in JMeter GUI or toggle `enabled="true"` / `enabled="false"` on the corresponding `<ThreadGroup>` element.

---

## Direct JMeter CLI Usage

If you prefer invoking JMeter directly without `run-test.sh`:

```bash
# Important: ensure '@' in the username is URL-encoded as '%40' for form post bodies
jmeter -n \
  -t chub-test.jmx \
  -Jhost=app-chub-test-weu-01-fad6buf3ejgffnh9.westeurope-01.azurewebsites.net \
  -Jprotocol=https \
  -Jport=443 \
  -Jusername=fatima.alzubaidi%40dge.gov.ae \
  -Jpassword=Testing123! \
  -Jthreads=50 \
  -Jrampup=15 \
  -l results/test.jtl \
  -j results/jmeter.log \
  -e -o results/report
```

---

## Results and HTML Reports

Each execution created with `run-test.sh` stores all run outputs in a timestamped folder:

```
results/
└── YYYYMMDD_HHMMSS/
    ├── jmeter.log          # Detailed execution log
    ├── results.jtl         # CSV metrics per sample
    └── report/             # Interactive HTML Dashboard
        ├── index.html      # Main dashboard page
        ├── statistics.json # Machine-readable summary stats
        └── content/        # CSS, JS, charts (APDEX, percentiles, throughput)
```

To view the dashboard, open `results/<timestamp>/report/index.html` in any web browser.
