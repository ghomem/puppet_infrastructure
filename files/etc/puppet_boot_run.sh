#!/bin/bash
set -u

LOG=/tmp/puppet_boot_run.log
LOCK_WAIT_MAX=120        # seconds to wait for apt/dpkg locks
PUPPET_TIMEOUT=900       # max seconds for this boot run (15 min)

echo "Puppet boot-run started at: $(date -Is)" > "$LOG"

# 1) If another puppet run is already in progress, do NOT compete. Just exit cleanly.
if /opt/puppetlabs/bin/puppet agent --configprint agent_catalog_run_lockfile >/dev/null 2>&1; then
  LOCKFILE="$(/opt/puppetlabs/bin/puppet agent --configprint agent_catalog_run_lockfile)"
  if [ -f "$LOCKFILE" ]; then
    echo "Another puppet run appears active (lockfile exists: $LOCKFILE). Skipping boot run." >> "$LOG"
    exit 0
  fi
fi

# 2) Avoid apt/dpkg lock contention during boot
start_ts=$(date +%s)
while true; do
  if ! lsof /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; then
    break
  fi
  now_ts=$(date +%s)
  if [ $((now_ts - start_ts)) -ge "$LOCK_WAIT_MAX" ]; then
    echo "Apt/dpkg locks still present after ${LOCK_WAIT_MAX}s; continuing anyway." >> "$LOG"
    break
  fi
  sleep 3
done

# 3) Run puppet with a hard timeout so systemd never waits forever
echo "Running puppet agent at: $(date -Is)" >> "$LOG"
if command -v timeout >/dev/null 2>&1; then
  timeout "$PUPPET_TIMEOUT" /opt/puppetlabs/bin/puppet agent -t >> "$LOG" 2>&1
  rc=$?
  if [ "$rc" -eq 124 ]; then
    echo "Puppet boot-run timed out after ${PUPPET_TIMEOUT}s." >> "$LOG"
    exit 0
  fi
  exit 0
else
  /opt/puppetlabs/bin/puppet agent -t >> "$LOG" 2>&1
  exit 0
fi
