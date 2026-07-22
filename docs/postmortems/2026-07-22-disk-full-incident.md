# Postmortem: Disk space exhaustion on idp-platform-dev

**Date:** 2026-07-22
**Severity:** High (root filesystem reached 97% capacity)
**Status:** Resolved
**Author:** SN

---

## Summary

The root filesystem on the idp-platform-dev EC2 instance was deliberately driven to 97% capacity by an unbounded log file with no rotation policy, simulating a runaway logging service. The incident was diagnosed and resolved within minutes using standard Linux disk-usage tooling, and a permanent prevention mechanism (logrotate with a size-based trigger) was implemented to stop recurrence.

## Timeline

- 03:16 - Runaway logging script created and made executable at /var/log/runaway-app/generate.sh
- 03:24 - Script confirmed not running after initial attempt (permission issue during first execution attempt)
- 03:2X - Script successfully started; began writing 1MB chunks of data to app.log in a continuous loop
- 03:3X - Disk usage observed climbing in real time via watch -n 2 df -h
- 03:4X - Disk usage reached 97% on root filesystem; script manually stopped
- 03:4X - Root cause confirmed via du -sh: app.log was consuming 5.6G
- 03:4X - Immediate remediation applied using truncate -s 0
- 03:4X - Verified disk usage returned to baseline (27%)
- 03:4X - Preventive fix implemented: logrotate config with 100MB size trigger

## Root cause

The runaway-app service (simulated) wrote continuously to a single log file with no size cap, no rotation schedule, and no monitoring alert on disk usage. In a real production scenario, this pattern commonly occurs when a service has a debug logging flag accidentally left enabled, or enters an error loop that logs on every retry attempt.

There was no logrotate configuration for this application prior to the incident, a gap that would exist for any newly deployed service unless explicitly configured.

## Diagnosis process

1. Confirmed the alert was real: df -h showed root filesystem at 97 percent (baseline was 27 percent)
2. Identified the largest consumer under /var using: sudo du -sh /var/log/* | sort -rh | head -10
3. Narrowed down to the specific file (/var/log/runaway-app/app.log, 5.6G) by drilling into the identified directory
4. Confirmed via du -sh that this single file accounted for nearly the entire disk's used space

## Resolution

Used truncate -s 0 /var/log/runaway-app/app.log rather than rm. Truncating empties the file's contents in place without deleting the file itself. This matters because if a process still holds an open file handle to a deleted file, the disk space is not actually released by the OS until that handle closes. Truncating avoids this failure mode entirely.

Verified resolution via df -h, confirming return to the 27 percent baseline.

## Prevention

Added /etc/logrotate.d/runaway-app with the following policy:

    /var/log/runaway-app/app.log {
        daily
        rotate 7
        maxsize 100M
        compress
        missingok
        notifempty
        copytruncate
    }

The maxsize 100M directive is the critical control. It forces rotation immediately once the file exceeds 100MB, independent of the daily schedule, preventing any single runaway log from ever consuming meaningful disk space again. copytruncate was used specifically because the writing process keeps the file open continuously; this rotation method avoids the same "space not released" issue described above.

Config validity was verified using logrotate -d (debug/dry-run mode) before relying on it.

## Follow-up actions

These would apply in a real production environment beyond this single portfolio incident:

- Add a CloudWatch alarm on disk utilization (alert at 80 percent root filesystem usage) so this class of incident is caught automatically rather than relying on manual observation
- Apply a default logrotate policy to all new services provisioned via the IDP platform, rather than configuring it reactively per-incident
- Consider moving high-volume application logs to a dedicated, separately-monitored volume rather than sharing the root filesystem

## Interview talking points

- Demonstrates real, not simulated-on-paper, incident response: alert, diagnose, resolve, prevent, in that order
- Shows the rm vs truncate distinction, a genuinely common Linux gotcha with open file handles
- Shows understanding of logrotate internals (copytruncate vs standard rotation, size-based vs time-based triggers)
- Connects to platform-level thinking in the follow-up actions: this stopped one specific instance from recurring, but the real fix at scale is making log rotation a default for every provisioned environment, not a per-incident fix
