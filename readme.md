# VPCCTL — Build Your Own Virtual Private Cloud (Linux Edition)

### 🌍 Overview

**VPCCTL** is a command-line tool that lets you **build your own virtual private cloud (VPC)** environment entirely using **Linux networking tools** — no cloud provider required.

It recreates the key features of AWS or GCP VPCs locally using:

* **Network namespaces** for isolation
* **veth pairs** for connectivity
* **Linux bridges** for internal routing
* **iptables** for NAT and firewalls

With this project, you can create multiple virtual VPCs, add public and private subnets, peer them together, control traffic with firewalls, and simulate real cloud networking — all on one Linux host.

It’s designed as part of a **DevOps learning project** to understand how cloud networking works from first principles.

---

## 🧠 Conceptual Architecture

Here’s how the system works visually:

```
+---------------------------------------------------------------+
|                     🖥️  Linux Host Machine                    |
|     (Uses namespaces, veth pairs, bridges, and iptables)      |
+---------------------------------------------------------------+
                                │
     ┌────────────────────────────────────────────────────┐
     │                        VPC 1                       │
     │                 (Bridge: br-vpc1)                  │
     │                                                    │
     │   +-------------------+        +-------------------+│
     │   | ns-vpc1-public    |        | ns-vpc1-private   |│
     │   | 10.10.1.0/24      |        | 10.10.2.0/24      |│
     │   +--------+----------+        +----------+--------+│
     │            |                             |          │
     │        veth pair                     veth pair      │
     └────────────────────────────────────────────────────┘
                                │
                         Peering link
                                │
     ┌────────────────────────────────────────────────────┐
     │                        VPC 2                       │
     │                 (Bridge: br-vpc2)                  │
     │                                                    │
     │   +-------------------+                            │
     │   | ns-vpc2-public    |                            │
     │   | 10.20.1.0/24      |                            │
     │   +--------+----------+                            │
     │            |                                       │
     │        veth pair                                  │
     └────────────────────────────────────────────────────┘

Each VPC:
- Has its own **bridge** (acts like a router/switch).
- Contains **subnets** (network namespaces).
- Uses **veth pairs** to connect subnets to the bridge.
- Can be **peered** with another VPC for intercommunication.
- Attempts to use **NAT** to access the Internet.
```

---

## ⚙️ Features

✅ Create and manage multiple VPCs
✅ Add public and private subnets
✅ Enable routing between subnets within a VPC
✅ Peer two VPCs for cross-communication
✅ Apply firewall policies (allow/deny by port and protocol)
✅ Full create → inspect → delete lifecycle
⚠️ NAT configuration attempted, but **not yet fully functional**

---

## 🧰 Requirements

You’ll need:

```bash
sudo apt install iproute2 iptables python3 -y
```

Make sure your user can run commands with `sudo`.

---

## 🚀 How to Use

### 1️⃣ Install the CLI

Copy the script to your system path and make it executable:

```bash
sudo cp vpcctl /usr/local/bin/
sudo chmod +x /usr/local/bin/vpcctl
```

---

### 2️⃣ Create Your First VPC

```bash
sudo vpcctl create-vpc --name vpc1 --cidr 10.10.0.0/16
```

---

### 3️⃣ Add Subnets

```bash
sudo vpcctl add-subnet --vpc vpc1 --name public --cidr 10.10.1.0/24 --public
sudo vpcctl add-subnet --vpc vpc1 --name private --cidr 10.10.2.0/24
```

---

### 4️⃣ Create Another VPC and Peer Them

```bash
sudo vpcctl create-vpc --name vpc2 --cidr 10.20.0.0/16
sudo vpcctl add-subnet --vpc vpc2 --name public --cidr 10.20.1.0/24 --public
sudo vpcctl peer-vpcs --a vpc1 --b vpc2
```

Once peered, the two VPCs can communicate through their bridges.

---

### 5️⃣ Inspect and Clean Up

Inspect:

```bash
sudo vpcctl inspect-vpc --name vpc1
```

Delete:

```bash
sudo vpcctl delete-vpc --name vpc1
```

---

## 🧪 Testing & Demonstration

To validate connectivity, use commands like:

```bash
# Within same VPC
sudo ip netns exec ns-vpc1-public ping 10.10.2.2

# Across peered VPCs
sudo ip netns exec ns-vpc1-public ping 10.20.1.2
```

If you’ve deployed a web server (like Python’s built-in HTTP server):

```bash
sudo ip netns exec ns-vpc1-public python3 -m http.server 80 &
sudo ip netns exec ns-vpc1-private curl 10.10.1.2:80
```

---

## ⚠️ NAT and Internet Access (Current Status)

This part of the project **did not work as expected**.

### What was implemented:

* A **veth pair** connects the host to the VPC bridge.
* A **MASQUERADE rule** was applied to translate internal IPs to the host’s external interface.
* **IP forwarding** was enabled on the host (`sysctl -w net.ipv4.ip_forward=1`).
* The **bridge and routes** were correctly set up inside namespaces.

### What went wrong:

Despite all these configurations, outbound Internet access from the VPC namespaces (e.g. `ping 8.8.8.8`) still fails with:

```
Destination Host Unreachable
```

### Likely Causes (Under Review):

* Missing bridge firewall forwarding (bridge traffic may bypass iptables by default).
* Possible missing `br_netfilter` module (bridge packets not passing through NAT).
* Potential routing mismatch between the VPC link and the host default route.

### Current Workaround:

For now, NAT remains **unresolved** — everything else (routing, peering, firewalls, and isolation) works perfectly.

If you’re familiar with **iptables**, **Linux bridge forwarding**, or **network namespace NAT setups**, I’d greatly appreciate any feedback or insight on how to fix the remaining NAT issue 🙏

---

## 🧹 Cleanup

To remove everything created by the project:

```bash
sudo vpcctl delete-vpc --name vpc1
sudo vpcctl delete-vpc --name vpc2
```

You can also manually clean up:

```bash
sudo ip netns del ns-vpc1-public
sudo ip netns del ns-vpc1-private
sudo ip netns del ns-vpc2-public
sudo ip link del br-vpc1
sudo ip link del br-vpc2
sudo iptables -F
sudo iptables -t nat -F
```

---

## 🧾 Summary

| Feature      | Status | Description                                 |
| ------------ | ------ | ------------------------------------------- |
| VPC Creation | ✅      | Fully working                               |
| Subnets      | ✅      | Works as expected                           |
| Routing      | ✅      | Works across subnets                        |
| Peering      | ✅      | Verified communication                      |
| Firewall     | ✅      | Allows/Drops rules correctly                |
| NAT          | ⚠️     | Implemented but not functional              |
| Teardown     | ✅      | Cleans up all namespaces, veth, and bridges |

---

## 💡 Future Improvements

* Fix NAT (bridge ↔ host routing)
* Support DNS resolution inside namespaces
* Add logging for connection attempts
* Add test suite for automated validation

---

## 🧑‍💻 Author’s Note

This project was built as part of a **DevOps networking challenge** to understand Linux networking and cloud VPC fundamentals from scratch.

It’s been an incredible deep dive into how real cloud platforms like AWS implement **VPCs, subnets, routing, and NAT gateways** at a low level.

Even though NAT remains unsolved, I’ve documented every step and welcome **feedback, suggestions, or pull requests** from anyone who’s solved this before.
