#!/usr/bin/env python3
import json, subprocess, sys

POLICY_FILE = "/var/lib/vpcctl/security_policy.json"
NAMESPACE = "ns-testvpc-private"  # 🔧 change if needed

def run(cmd):
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)

def main():
    with open(POLICY_FILE) as f:
        policy = json.load(f)

    for rule in policy["ingress"]:
        port, proto, action = rule["port"], rule["protocol"], rule["action"]

        if action == "allow":
            run(["sudo", "ip", "netns", "exec", NAMESPACE,
                 "iptables", "-A", "INPUT",
                 "-p", proto, "--dport", str(port), "-j", "ACCEPT"])
        elif action == "deny":
            run(["sudo", "ip", "netns", "exec", NAMESPACE,
                 "iptables", "-A", "INPUT",
                 "-p", proto, "--dport", str(port), "-j", "DROP"])

    # Default policy: drop everything else
    run(["sudo", "ip", "netns", "exec", NAMESPACE,
         "iptables", "-P", "INPUT", "DROP"])

if __name__ == "__main__":
    main()
