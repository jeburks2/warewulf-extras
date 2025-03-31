# Warewulf DNS Sync Script

**Author:** Josh Burks (<jeburks2@asu.edu>)  
**Purpose:** Syncs Warewulf node IPs with Technitium DNS via API.  
**Performance:** Processes ~800 nodes in ~1.2 seconds.  
**Recommended Usage:** Run via cron every 2 hours.

## Description

This script uses `wwctl` to retrieve IP assignments for Warewulf-managed nodes and compares them against current A records in Technitium DNS. If differences are found, it updates the records using Technitium's HTTP API.

Zones are automatically inferred from hostnames. For ASU, this looks like:

- `s*` or `d*` → `sol.rc.asu.edu`
- `p*` → `phx.rc.asu.edu`

## Requirements

- Python 3.6+
- `dnspython==1.*`
- `requests`
- Access to Technitium DNS API
- Warewulf with `wwctl` available in PATH

These are installable with dnf on Rocky 8

```bash
dnf install python3-dns python3-requests
```

## Configuration

Edit the script to match your environment:

```python
DNS_SERVER = "192.168.1.100"       # Technitium DNS server IP
KEY = "your_api_key_here"          # Replace with your actual API key
LOG_FILE = "/var/log/dns_sync.log" # Location for logs
```

You will also need to edit the zone information to match your environment

## Usage

Dry Run

```bash
./sync_dns.py --dryrun
```

Logs changes that would be made without applying them.

Live Run

```bash
./sync_dns.py
```

Applies DNS updates via API.

Cron Example
Add to root's crontab:

```cron
0 8-20/2 * * * /usr/bin/python3 /usr/local/bin/dns_sync.py
```

### Notes

Requires zone/domain structure consistent with hostname prefix.

Logs always written to /var/log/dns_sync.log.

Script is idempotent; will not update records unnecessarily.
