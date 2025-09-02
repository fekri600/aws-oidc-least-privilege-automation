#!/usr/bin/env python3
import sys
import json
import ipaddress
import os
import time
import tempfile

# ─── Fixed Policy ─────────────────────────────────────────────────────────────
BASE_POOL     = "10.0.0.0/8"   # all VPCs allocated from this pool
VPC_PREFIX    = 16             # VPCs are always /16
SUBNET_PREFIX = 24             # subnets are always /24

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
STATE_FILE   = os.path.join(SCRIPT_DIR, "ipam_state.json")
LOCK_FILE    = os.path.join(SCRIPT_DIR, "ipam_state.lock")

# ─── Simple file lock ─────────────────────────────────────────────────────────
class FileLock:
    def __init__(self, path, timeout=30, poll=0.1):
        self.path = path
        self.timeout = timeout
        self.poll = poll
        self.fd = None

    def __enter__(self):
        start = time.time()
        while True:
            try:
                self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_RDWR)
                return self
            except FileExistsError:
                if time.time() - start > self.timeout:
                    raise TimeoutError(f"Timeout acquiring lock {self.path}")
                time.sleep(self.poll)

    def __exit__(self, exc_type, exc, tb):
        try:
            if self.fd is not None:
                os.close(self.fd)
            if os.path.exists(self.path):
                os.unlink(self.path)
        except Exception:
            pass

# ─── JSON helpers ─────────────────────────────────────────────────────────────
def load_json(path, default):
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            return default
    return default

def atomic_save_json(path, data):
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=d, delete=False) as tmp:
        json.dump(data, tmp, indent=2)
        tmp.flush()
        os.fsync(tmp.fileno())
        tmp_path = tmp.name
    os.replace(tmp_path, path)

def allocate_next(super_cidr, used, prefix):
    net = ipaddress.ip_network(super_cidr)
    for cand in net.subnets(new_prefix=prefix):
        c = str(cand)
        if c not in used:
            used.add(c)
            return c
    raise RuntimeError(f"no free blocks inside {super_cidr} for /{prefix}")

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    q         = json.load(sys.stdin)
    env       = q.get("env", "default").strip()
    vpc_name  = q.get("vpc_name", "default").strip()
    mode      = q.get("resource_type", "subnet").strip()

    vpc_key = f"{env}|{vpc_name}"

    with FileLock(LOCK_FILE):
        state = load_json(STATE_FILE, {"vpcs": {}, "subnets": {}})
        vpcs = state.setdefault("vpcs", {})
        subs = state.setdefault("subnets", {})

        # ─ VPC Allocation ─────────────────────────────────────────────────────
        if mode == "vpc":
            if vpc_key in vpcs:
                cidr = vpcs[vpc_key]["cidr"]
            else:
                supernet = ipaddress.ip_network(BASE_POOL)
                used = {entry["cidr"] for entry in vpcs.values()}
                cidr = None
                for cand in supernet.subnets(new_prefix=VPC_PREFIX):
                    c = str(cand)
                    if c not in used:
                        cidr = c
                        vpcs[vpc_key] = {"cidr": cidr}
                        break
                if cidr is None:
                    print(json.dumps({"error": "no free /16s in 10.0.0.0/8"}), file=sys.stderr)
                    sys.exit(1)

            atomic_save_json(STATE_FILE, state)
            print(json.dumps({"cidr": cidr}))
            return

        # ─ Subnet Allocation ──────────────────────────────────────────────────
        if mode == "subnet":
            if vpc_key not in vpcs:
                print(json.dumps({"error": f"VPC for '{vpc_key}' not allocated yet. Run resource_type='vpc' first."}), file=sys.stderr)
                sys.exit(1)

            vpc_cidr = vpcs[vpc_key]["cidr"]
            pub_count  = int(q.get("public_count", 0))
            priv_count = int(q.get("private_count", 0))

            alloc = subs.setdefault(
                vpc_key,
                {"vpc_cidr": vpc_cidr, "public": [], "private": [], "prefix": SUBNET_PREFIX}
            )

            if alloc["vpc_cidr"] != vpc_cidr:
                print(json.dumps({"error": f"State VPC '{alloc['vpc_cidr']}' != current VPC '{vpc_cidr}' for key '{vpc_key}'"}), file=sys.stderr)
                sys.exit(1)

            used = set(alloc["public"] + alloc["private"])
            while len(alloc["public"]) < pub_count:
                alloc["public"].append(allocate_next(vpc_cidr, used, SUBNET_PREFIX))
            while len(alloc["private"]) < priv_count:
                alloc["private"].append(allocate_next(vpc_cidr, used, SUBNET_PREFIX))

            subs[vpc_key] = alloc
            atomic_save_json(STATE_FILE, state)

            print(json.dumps({
                "public_subnets":  ",".join(alloc["public"]),
                "private_subnets": ",".join(alloc["private"])
            }))
            return

        # ─ Reset Allocation (destroy) ─────────────────────────────────────────
        if mode == "reset":
            removed = False
            if vpc_key in vpcs:
                del vpcs[vpc_key]
                removed = True
            if vpc_key in subs:
                del subs[vpc_key]
                removed = True
            atomic_save_json(STATE_FILE, state)
            print(json.dumps({"status": f"released {vpc_key}", "removed": removed}))
            return

        # ─ Unknown Mode ───────────────────────────────────────────────────────
        print(json.dumps({"error": f"unknown resource_type: {mode}"}), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
