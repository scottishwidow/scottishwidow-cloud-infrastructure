# Honeynet

The `honeynet` environment: hosts that invite attacks so that Suricata has real hostile traffic to inspect. It is hostile by design. No other environment has a path into it, and its only path out is the Sensor's write-only path to the Corpus.

## Language

**Honeynet**:
The isolated set of hosts that attract and observe attacks. It has its own Hetzner project, network and SSH key. No other environment has a path into it, and its only path out is the Sensor's write-only path to the Corpus.
_Avoid_: Lab, sandbox, DMZ

**Honeypot**:
A host with no public IP that runs emulated services to attract attacks. Nothing on it is trusted.
_Avoid_: Decoy, trap, target

**Persona**:
The one host identity that every Honeypot service claims: hostname, OS, kernel and service versions. It is Ubuntu 22.04.
_Avoid_: Profile, disguise, cover

**Dark Port**:
A honeypot port that the Sensor forwards although no service answers it. Suricata still inspects the traffic.
_Avoid_: Closed port, filtered port, unused port

**Sensor**:
The single Honeynet host with a public IPv4. Every packet between the internet and a Honeypot passes through it, and Suricata on it inspects them.
_Avoid_: Gateway, router, firewall, IDS box

**Log Volume**:
The Hetzner Volume that holds the Sensor logs and the EveBox database. It outlives the Sensor.
_Avoid_: Disk, data volume, log disk

**Containment**:
The rule that no new connection leaves a Honeypot for the internet. Replies to inbound connections are allowed.
_Avoid_: Data control, egress filtering, sandboxing

**Sinkhole**:
The fake internet service that answers a Honeypot's outbound HTTP, HTTPS and DNS in place of the real destination. A connection to the Sinkhole never leaves the Honeynet, so Containment still holds.
_Avoid_: Fake internet, INetSim, egress proxy

**Session Evidence**:
The record of what an intruder typed, tried and downloaded on a Honeypot. Cowrie and OpenCanary write it.
_Avoid_: Transcript, capture, payload, session log

**Corpus**:
The retained telemetry from every Honeynet source. It is held outside the Honeynet hosts and outlives any of them.
_Avoid_: Data lake, archive, log store, warehouse

**Hunt**:
A search for hostile activity that starts from a hypothesis and is written as SQL against the Corpus.
_Avoid_: Investigation, triage, analysis, threat hunt

**Hunt Host**:
The host that queries the Corpus. It is not a Honeynet host, it holds a credential, and it is destroyed with the Honeynet.
_Avoid_: Analysis box, jump host, workstation
