---
date: 2026-09-18
day: 2
topic: §21 VPC — networking end to end
tags: [sprint, vpc, networking]
---

> [!NOTE]
> **Goal today:** Work through Maarek §21 VPC in full and come out able to describe how traffic gets in and out of a VPC.
> **Done means:** Section finished, notes and diagram committed, announcement post published.

## Checklist
- [x] §21 VPC watched in full
- [x] CIDR maths comfortable: /16, /24, /26, /28 without a calculator
- [x] Can state the SG vs NACL difference in one sentence each
- [x] Can state NAT gateway vs NAT instance in one sentence each
- [x] VPC diagram made and committed to `docs/diagrams/`
- [x] LinkedIn sprint announcement published
- [x] 60 practice questions
- [x] Notes committed

## What I built
Notes, not infrastructure. Building is paused until after the 30 September exam, so today's output is the Section 21 section notes, the VPC diagram, and the comparison tables below.

## Commands worth keeping
Read-only, safe to run any time. The last two are the ones that cost money if left running.
```bash
# What exists right now
aws ec2 describe-vpcs --query 'Vpcs[].{id:VpcId,cidr:CidrBlock,default:IsDefault}' --output table
aws ec2 describe-subnets --query 'Subnets[].{id:SubnetId,az:AvailabilityZone,cidr:CidrBlock,public:MapPublicIpOnLaunch}' --output table
aws ec2 describe-route-tables --query 'RouteTables[].{id:RouteTableId,routes:Routes[].DestinationCidrBlock}'

# The two things that cost money if left running
aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].{ip:PublicIp,assoc:AssociationId}'

# Nightly sweep
bash scripts/nightly-check.sh
```

## What broke
| Error | Cause | Fix |
| ----- | ----- | --- |
| Practice question: an EC2 instance can't reach the internet through an IGW. Picked the missing route table entry; the answer was the security group | Security groups are stateful, so outbound connections are allowed back in regardless of inbound rules | The rule: stateful SG, stateless NACL. Outbound-only problems are almost never the SG |
| Kept reaching for the SG to block a single IP address | Security groups only hold allow rules, so there is nothing to deny with | Blocking an IP is a NACL job. It is the only place a deny rule exists |

## Key points from the slides

**CIDR**
- Two parts: a base IP and a subnet mask. The mask says how many bits can change.
- /32 = 1 IP, /31 = 2, /30 = 4, /29 = 8, /28 = 16, /27 = 32, /26 = 64, /24 = 256, /16 = 65,536. Each step down doubles it.
- 0.0.0.0/0 means every IP.

**Private IP ranges (IANA)**
- 10.0.0.0/8: big networks
- 172.16.0.0/12: the AWS default VPC sits in this range
- 192.168.0.0/16: home networks
- Everything else is public.

**VPC**
- Max 5 VPCs per region (soft limit), max 5 CIDRs per VPC.
- Each CIDR: minimum /28 (16 IPs), maximum /16 (65,536 IPs).
- Only private ranges allowed. CIDRs must not overlap with networks you'll connect to.
- Every new account gets a default VPC, with internet connectivity and public IPv4 on instances.

**Subnets**
- Tied to one AZ. AWS reserves 5 addresses in every subnet: the first four and the last one.
- In 10.0.0.0/24: `.0` network address, `.1` VPC router, `.2` Amazon DNS, `.3` reserved for future use, `.255` broadcast.
- Exam pattern: need 29 usable addresses, so a /27 (32 − 5 = 27) is too small. Go to /26.

**Internet gateway**
- One per VPC, one VPC per IGW. Horizontally scaled and redundant.
- The IGW alone gives nothing. The route table has to point at it.

**Bastion host**
- Public-subnet EC2 you SSH into, which then reaches private instances.
- Its SG allows port 22 inbound from a restricted CIDR, not from anywhere.
- The private instances' SG allows the bastion's security group or private IP.

**NAT instance (outdated, still examined)**
- Self-managed EC2 in a public subnet, giving private instances outbound internet.
- Must disable the source/destination check and attach an Elastic IP.
- Not highly available by default: needs an ASG across AZs and a resilient user-data script.
- Bandwidth depends on instance type. You manage the security groups.

**NAT gateway**
- AWS-managed, no admin, no security groups to manage.
- Created in one AZ, uses an Elastic IP, needs an IGW behind it (private subnet → NATGW → IGW).
- 5 Gbps, scaling automatically to 100 Gbps.
- Cannot be used by instances in the same subnet, only from other subnets.
- Resilient within its AZ only. For fault tolerance, one per AZ. No cross-AZ failover is needed, because if the AZ is down there's nothing to NAT.
- Billed per hour and per GB processed.

| | NAT gateway | NAT instance |
|---|---|---|
| Availability | Highly available within an AZ | Script-managed failover |
| Bandwidth | Up to 100 Gbps | Depends on instance type |
| Maintenance | AWS | You (OS, software) |
| Cost | Per hour + data processed | Per hour + instance type and size |
| Security groups | None | Yes |
| Use as bastion | No | Yes |

**Regional NAT gateway (RNAT)**
- Highly available NAT associated with the VPC, shared across AZs, with its own route tables.
- Removes the per-AZ deployment and the need for public subnets to host it.
- Detects resources in a new AZ and expands there automatically.

**NACL**
- Subnet-level firewall, one NACL per subnet, new subnets get the default NACL.
- Rules numbered 1–32766, lowest number wins, first match decides. AWS suggests increments of 100.
- Last rule is `*`, denying anything unmatched. A newly created NACL denies everything.
- The default NACL allows everything in and out. Don't edit it, create custom ones.
- The only way to block a single IP address.

**Ephemeral ports**
- The client picks a high port and expects the reply there. Windows and IANA: 49152–65535. Many Linux kernels: 32768–60999.
- Because NACLs are stateless, the return path needs its own rule covering that range. This is the thing that breaks a two-tier NACL setup.

| | Security group | NACL |
|---|---|---|
| Level | Instance | Subnet |
| Rules | Allow only | Allow and deny |
| State | Stateful, return traffic allowed automatically | Stateless, return traffic needs a rule |
| Evaluation | All rules considered together | In order, lowest number first, first match wins |
| Applies | When someone attaches it | Automatically to every instance in the subnet |

**VPC peering**
- Private connection between two VPCs, made to behave as one network.
- CIDRs must not overlap. Not transitive: every pair needs its own peering.
- Route tables in both VPCs must be updated.
- Works across accounts and regions. You can reference a security group in a peered VPC across accounts in the same region.

**VPC endpoints (PrivateLink)**
- Reach AWS services over the private network instead of the public internet. Removes the need for an IGW or NAT.
- **Gateway endpoint:** a route table target. S3 and DynamoDB only. Free. No security groups.
- **Interface endpoint:** an ENI with a private IP, needs a security group. Most services. Billed per hour and per GB.
- For S3, gateway is the exam's default answer. Interface wins when access comes from on-premises (VPN or Direct Connect), another VPC, or another region.
- Lambda in a VPC reaching DynamoDB: a gateway endpoint plus a route table change, rather than NAT gateway and IGW.
- When an endpoint misbehaves, check DNS resolution in the VPC and the route tables.

**VPC flow logs**
- Capture IP traffic at VPC, subnet, or ENI level, including AWS-managed interfaces (RDS, ElastiCache, Redshift, WorkSpaces, NAT GW, Transit Gateway).
- Destinations: S3, CloudWatch Logs, Kinesis Data Firehose.
- Fields that matter: srcaddr, dstaddr, srcport, dstport, and ACTION.
- Troubleshooting rule: inbound REJECT means NACL or SG. Inbound ACCEPT with outbound REJECT means the NACL, because the SG would have allowed the return traffic itself.
- Query with Athena over S3, or CloudWatch Logs Insights.

**Site-to-Site VPN**
- Virtual private gateway (VGW) on the AWS side, customer gateway (CGW) on yours. Runs over the public internet.
- The CGW needs a public routable IP, or the public IP of the NAT device if it sits behind NAT-T.
- Enable route propagation for the VGW on the subnet route tables.
- **VPN CloudHub:** low-cost hub-and-spoke between multiple sites over existing VPN connections.

**Direct Connect**
- Dedicated private line from your data centre to AWS, via a Direct Connect location.
- Reaches both public (S3) and private (EC2) resources on the same connection. Supports IPv4 and IPv6.
- **Direct Connect gateway:** one connection serving VPCs in several regions on the same account.
- Dedicated connections: 1 Gbps to 400 Gbps. Hosted connections: 50 Mbps to 25 Gbps, through a partner. Lead times often over a month.
- Not encrypted in transit, though private. Add a VPN over it for IPsec encryption.
- Resiliency: a second connection at another location, or separate devices at multiple locations for maximum resilience. A Site-to-Site VPN is the cheap backup.

**Transit Gateway**
- Hub-and-spoke for thousands of VPCs and on-premises networks. Transitive, unlike peering.
- Regional, works cross-region, shareable across accounts with Resource Access Manager. TGWs can peer with each other.
- Route tables control which VPCs can talk to which.
- The only AWS service supporting IP multicast.
- **ECMP:** multiple Site-to-Site VPN connections carrying traffic in parallel. A VPN to a VGW gives 1.25 Gbps; to a TGW with ECMP, 2.5 Gbps per connection, so two give 5 Gbps and three give 7.5.

**Traffic mirroring**
- Copy traffic from ENIs to an ENI or NLB for inspection. Source and target can sit in different VPCs via peering.
- Filter or truncate packets. For content inspection, threat monitoring, troubleshooting.

**IPv6**
- Every IPv6 address in AWS is public and internet-routable. No private ranges.
- IPv4 can't be disabled, so a VPC runs dual-stack.
- **Egress-only internet gateway:** the IPv6 equivalent of a NAT gateway. Outbound only, and route tables must be updated.
- Troubleshooting: if an instance won't launch, it's exhausted IPv4 addresses in the subnet, never IPv6. Add another IPv4 CIDR.

**Networking costs**
- NAT gateway: $0.045 per hour plus $0.045 per GB processed, and data out to S3 cross-region is charged again. A gateway endpoint avoids both, and is free.
- S3 ingress is free. S3 to internet $0.09/GB. CloudFront to internet $0.085/GB. S3 to CloudFront $0.00.
- Transfer Acceleration adds $0.04–$0.08 per GB for 50–500% faster transfers.
- Same-AZ traffic on private IPs is free. Cross-AZ costs per GB, and using public or elastic IPs costs more than private ones.
- Ingress into AWS is typically free. Keep traffic inside AWS to minimise egress.

**Network protection**
- NACLs, security groups, WAF, Shield and Shield Advanced, Firewall Manager across accounts.
- **AWS Network Firewall:** protects an entire VPC, layers 3 to 7, any direction — VPC to VPC, outbound, inbound, and to or from Direct Connect and VPN. Built on Gateway Load Balancer internally.
- Thousands of rules: IP and port, protocol, stateful domain lists, regex pattern matching. Allow, drop, or alert. Logs to S3, CloudWatch Logs, Kinesis Data Firehose.

## In my own words
A VPC is my own slice of the AWS network, cut up into subnets that each live in one AZ. What makes a subnet public isn't a setting, it's a route to an internet gateway. Private subnets get out through a NAT gateway and nothing gets back in, or skip the internet entirely with an endpoint when the target is an AWS service. Security groups wrap instances and remember connections. NACLs wrap subnets and don't, which is why the return path needs its own rule.

## Still unclear
- [ ] Writing NACL rules for a two-tier setup from scratch: which ephemeral range goes on which side, in both directions
- [ ] When a regional NAT gateway is the right answer instead of one NAT gateway per AZ
- [ ] Direct Connect resiliency levels: what separates "high" from "maximum" in practice
- [ ] Reading a flow log line cold and naming the SG or NACL that rejected it

## Shipped
| | |
|---|---|
| Artifact | `notes/days/day-02-vpc.md`, `docs/diagrams/vpc.png` |
| Commit | `docs(vpc): section 21 notes, comparison tables and diagram` |
| Post | Sprint announcement |

## Tomorrow's first tiny task
Open Section 5 and watch the first lecture before doing anything else.
