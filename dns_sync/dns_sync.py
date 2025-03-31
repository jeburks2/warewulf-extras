#!/usr/bin/env python3

# Blame: Josh Burks <jeburks2@asu.edu> 
# Syncs Warewulf IP information to the Technitium DNS API

# Processing 800 nodes takes about 1.2 seconds. Setup in cron to run every 2 hours

import argparse
import csv
import logging
import subprocess
from io import StringIO

import dns.resolver
import requests

DNS_SERVER = "192.168.1.100" # Technitium DNS server IP
API = f"http://{DNS_SERVER}:5380/api" # Technitium DNS API endpoint
KEY = "your_api_key_here" # Replace with your actual API key
LOG_FILE = "/var/log/dns_sync.log"

def main():
    # --- Argparse for dryrun ---
    parser = argparse.ArgumentParser()
    parser.add_argument("--dryrun", action="store_true", help="Show changes without applying them")
    args = parser.parse_args()

    # --- Logging ---
    # Always log to file
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
    logger.addHandler(file_handler)
    # If dryrun, also log to stdout
    if args.dryrun:
        stream_handler = logging.StreamHandler()
        stream_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
        logger.addHandler(stream_handler)

    # --- DNS Resolver ---
    resolver = dns.resolver.Resolver()
    resolver.nameservers = [DNS_SERVER]

    # --- Get node list ---
    cmd = "wwctl node list --net | grep -i ethernet | awk '{print $1\",\"$4}'" # Use awk to format the output into CSV
    output = subprocess.check_output(cmd, shell=True).decode()

    records = []
    reader = csv.reader(StringIO(output))
    for row in reader:
        if len(row) != 2:
            continue
        host, ip = row
        # Our Warewulf hosts are not FQDNs, so we need to add the zone based on the host name
        # You will need to change this to match your environment
        if host.startswith(('s', 'd')): # Check if the host starts with 's' or 'd'
            zone = "sol.rc.asu.edu" # If so, set the zone to sol.rc.asu.edu as this is part of the Sol cluster
        elif host.startswith('p'): # Check if the host starts with 'p'
            zone = "phx.rc.asu.edu" # If so, set the zone to phx.rc.asu.edu as this is part of the Phoenix cluster
        else:
            continue
        fqdn = f"{host}.{zone}"
        records.append((host, ip, zone, fqdn))

    logging.info(f"Starting DNS sync run with {len(records)} records")

    # --- Sequential run ---
    updated = 0
    skipped = 0

    for host, ip, zone, fqdn in records:
        try:
            current_ip = resolver.query(fqdn, "A")[0].to_text()
        except Exception:
            current_ip = None

        if current_ip != ip:
            msg = f"{fqdn} mismatch: DNS={current_ip}, WWCTL={ip}"
            if args.dryrun:
                logging.info(f"DRYRUN: {msg}")
            else:
                logging.info(f"UPDATING: {msg}")
                if current_ip is None:
                    requests.post(
                        f"{API}/zones/records/add",
                        params={
                            "token": KEY,
                            "domain": fqdn,
                            "zone": zone,
                            "type": "A",
                            "ipAddress": ip,
                            "ttl": 300,
                            "ptr": "false"
                        }
                    )
                else:
                    requests.post(
                        f"{API}/zones/records/update",
                        params={
                            "token": KEY,
                            "domain": fqdn,
                            "zone": zone,
                            "type": "A",
                            "ipAddress": current_ip,
                            "newIpAddress": ip,
                            "ttl": 300,
                            "ptr": "false"
                        }
                    )
            updated += 1
        else:
            skipped += 1

    if args.dryrun:
        logging.info(f"DRYRUN complete: {skipped} in sync, {updated} would be updated")
    else:
        logging.info(f"Finished DNS sync: {skipped} in sync, {updated} updated")
        
if __name__ == "__main__":
    main()