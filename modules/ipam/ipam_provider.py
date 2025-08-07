#!/usr/bin/env python3
import sys
import json
import ipaddress
import os

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
STATE_FILE  = os.path.join(SCRIPT_DIR, "ipam_state.json")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "ipam_output.json")

# ─── Helpers ─────────────────────────────────────────────────────────────────
def load_json(path, default):
    if os.path.exists(path):
        try:
            return json.load(open(path))
        except json.JSONDecodeError:
            return default
    return default

def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

def allocate_next(super_cidr, used, prefix):
    """Return next free subnet of size /prefix inside super_cidr."""
    net = ipaddress.ip_network(super_cidr)
    for cand in net.subnets(new_prefix=prefix):
        c = str(cand)
        if c not in used:
            used.add(c)
            return c
    raise RuntimeError("no free blocks")

# ─── Main ────────────────────────────────────────────────────────────────────
def main():
    q          = json.load(sys.stdin)
    env        = q.get("env", "default")
    mode       = q.get("resource_type", "subnet")
    prefix     = int(q.get("prefix", 24))

    # Load or initialize state
    state      = load_json(STATE_FILE, {"vpc_allocations": {}, "subnet_allocations": {}})
    vmap       = state.setdefault("vpc_allocations", {})
    smap       = state.setdefault("subnet_allocations", {})
    env_subnets= smap.setdefault(env, {"public": [], "private": []})

    # ─ VPC Allocation ──────────────────────────────────────────────────────────
    if mode == "vpc":
        base = q["base_cidr"]
        # Always use the same key so we track all envs under that base
        key  = f"vpc::{base}/{prefix}"
        # If env already has a VPC, return it
        if env in vmap:
            cidr = vmap[env]
        else:
            # Step through 10.0.0.0/16, 10.1.0.0/16, … up to 10.255.0.0/16
            supernet = ipaddress.ip_network(base)
            start    = int(supernet.network_address)
            stride   = 2 ** (supernet.max_prefixlen - prefix)
            cidr     = None
            for i in range(256):
                cand_net = ipaddress.ip_network((start + i*stride, prefix))
                c        = str(cand_net)
                if c not in vmap.values():
                    cidr = c
                    vmap[env] = cidr
                    break
            if cidr is None:
                print(json.dumps({"error": "no free VPC /16s"}), file=sys.stderr)
                sys.exit(1)

        # Persist and emit
        save_json(STATE_FILE, state)
        # Update human-readable output file
        out = load_json(OUTPUT_FILE, {})
        entry = out.get(env, {})
        entry["vpc"] = cidr
        out[env] = entry
        save_json(OUTPUT_FILE, out)
        # Terraform wants a flat map<string,string>
        print(json.dumps({"cidr": cidr}))
        return

    # ─ Subnet Allocation ──────────────────────────────────────────────────────
    vpc_cidr    = q["vpc_cidr"]
    pub_count   = int(q.get("public_count", 0))
    priv_count  = int(q.get("private_count", 0))

    # Build used set from existing public+private subnets
    used = set(env_subnets["public"] + env_subnets["private"])

    # Allocate any additional public subnets
    while len(env_subnets["public"]) < pub_count:
        new_cidr = allocate_next(vpc_cidr, used, prefix)
        env_subnets["public"].append(new_cidr)

    # Allocate any additional private subnets
    while len(env_subnets["private"]) < priv_count:
        new_cidr = allocate_next(vpc_cidr, used, prefix)
        env_subnets["private"].append(new_cidr)

    # Persist state
    smap[env] = env_subnets
    save_json(STATE_FILE, state)

    # Update output file
    out = load_json(OUTPUT_FILE, {})
    entry = out.get(env, {})
    entry["public_subnets"]  = env_subnets["public"]
    entry["private_subnets"] = env_subnets["private"]
    out[env] = entry
    save_json(OUTPUT_FILE, out)

    # Emit results as CSV strings for Terraform
    print(json.dumps({
        "public_subnets":  ",".join(env_subnets["public"]),
        "private_subnets": ",".join(env_subnets["private"])
    }))

if __name__ == "__main__":
    main()
