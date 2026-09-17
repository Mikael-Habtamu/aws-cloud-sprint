---
date: 2026-09-15
day: 1
topic: Account, identity, and going public (IAM)
tags: [sprint, iam]
---

> [!NOTE]
> **Goal today:** Secure the AWS account, learn IAM, set up the repo and profiles, and go public.
> **Done means:** Every item on the plan's Day 1 checklist is either done or deliberately moved.

## Checklist
- [x] SAA-C03 booked (30 Sept = sprint Day 16; the plan assumed Day 12) and ESL +30 min approved
- [x] MFA on root, IAM admin user, $15 budget alarm live
- [x] AWS CLI installed and configured (region eu-north-1)
- [x] IAM lab: roles assumed from the CLI, AccessDenied errors practised
- [x] Repo `~/projects/aws-cloud-sprint` public on GitHub, with `.gitignore`, `.gitattributes`, README and folders
- [x] GitHub profile and LinkedIn rewritten
- [x] `scripts/nightly-check.sh` written, run and committed
- [ ] Domain: moved. The site launches on the free CloudFront URL first; applied for the GitHub Student Developer Pack for a free domain
- [ ] Linux gaps (SSH keys, permissions, systemctl, journalctl): moved to Day 3
- [ ] Baseline 3-minute recording: IAM roles and why they beat access keys
- [x] LinkedIn sprint announcement (15 Sept – 14 Oct)
- [ ] This note committed and pushed

## What I built
My AWS account is secured: root has MFA, daily work goes through an IAM admin user, and a $15 budget alarm watches spending. The AWS CLI is installed and set to eu-north-1. I assumed IAM roles from the CLI and triggered AccessDenied errors on purpose. The sprint repo is public on GitHub with `scripts/nightly-check.sh` committed.

## Commands worth keeping
```bash
# Show the CLI's default region (prints eu-north-1)
aws configure get region

# Set up CLI credentials, default region and output format
aws configure

# Assume a role. The account ID fills itself in.
# GUESS: role name "ReadOnlyRole" and session name "day1-lab" are examples; use your lab role's real name
aws sts assume-role \
  --role-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ReadOnlyRole" \
  --role-session-name day1-lab

# Run the nightly cost sweep (works whether or not the file is executable)
bash scripts/nightly-check.sh

# Add the site and docs folders to the repo
mkdir -p site docs/diagrams docs/writeups
touch site/.gitkeep docs/diagrams/.gitkeep docs/writeups/.gitkeep
git add site docs
git commit -m "chore: add site and docs folders"
```

## What broke
| Error | Cause | Fix |
| ----- | ----- | --- |
| AccessDenied in the role lab. GUESS, a typical example: `An error occurred (AccessDenied) when calling the CreateBucket operation: Access Denied` | The assumed role only had read permissions, so the write action was implicitly denied | Expected result; switched back to the admin profile (or added the permission to the role) |
| Cost Explorer step in `nightly-check.sh` errors | New account: Cost Explorer data not ingested yet (expected) | None needed; wait for the data |

## Key points from the slides

**IAM: users and groups**
- IAM = Identity and Access Management. It's a **global** service.
- The **root account** is created by default. Don't use it or share it.
- **Users** are people in your organisation and can be grouped.
- **Groups** contain only users, never other groups.
- A user can be in no group, one group, or several.

**Policy inheritance**
- A policy attached to a group applies to every user in that group.
- A user in two groups gets both groups' policies (Charles: Developers + Audit Team; David: Audit Team + Operations).

**Policy structure (JSON)**
- `Version`: always `"2012-10-17"`
- `Id`: optional identifier for the policy
- `Statement`: required, one or more. Each statement has:
  - `Sid`: optional identifier for the statement
  - `Effect`: `Allow` or `Deny`
  - `Principal`: the account/user/role the policy applies to
  - `Action`: the actions allowed or denied
  - `Resource`: the resources the actions apply to
  - `Condition`: optional, when the policy is in effect

The slide's example. The ARNs are cut off on the slide, so the account ID and bucket name below are standard AWS example values, not what the slide shows:
```json
{
  "Version": "2012-10-17",
  "Id": "S3-Account-Permissions",
  "Statement": [
    {
      "Sid": "1",
      "Effect": "Allow",
      "Principal": { "AWS": ["arn:aws:iam::123456789012:root"] },
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::mybucket/*"]
    }
  ]
}
```

**Policy evaluation** (from the plan's Day 1 doc page, not the slides)
- An explicit Deny always wins.
- Otherwise, access is denied unless a policy allows it.

**SCP: Service Control Policy** (not on the slides or in the plan; exam topic)
- Part of **AWS Organizations**, for managing many accounts together.
- Sets the **maximum** permissions for an account. It never grants anything by itself.
- An action works only if the SCP allows it **and** an IAM policy allows it.
- Applies to every user and role in the account, **including its root user**.
- Doesn't apply to the organisation's management account.
- Example: an SCP denying all regions except eu-north-1 stops even an admin from launching elsewhere.
- Doesn't affect me yet: my account is standalone, not in an organisation.

**MFA**
- MFA = a password you **know** + a security device you **own**.
- Protect the root account and IAM users with it.
- Main benefit: if a password is stolen or hacked, the account isn't compromised.
- Device options:
  - **Virtual MFA device** (Google Authenticator, Authy; phone only): multiple tokens on one device
  - **U2F security key** (YubiKey, third party): multiple root and IAM users on one key
  - **Hardware key fob** (Gemalto, third party)
  - **Hardware key fob for AWS GovCloud (US)** (SurePassID, third party)

**Access keys**
- An access key ID plus a secret access key. Never share them.

**AWS CLI**
- Lets you work with AWS services from the command line.
- Direct access to the public APIs of AWS services; you can script resource management.
- Open source; an alternative to the Management Console.

**AWS SDK**
- Language-specific libraries for accessing and managing AWS services from code, embedded in your application.
- SDKs: JavaScript, Python, PHP, .NET, Ruby, Java, Go, Node.js, C++. Mobile SDKs (Android, iOS). IoT device SDKs (Embedded C, Arduino).
- The AWS CLI is built on the AWS SDK for Python.

**IAM roles for services**
- Some AWS services need to act on your behalf; you give them permissions through IAM roles.
- Common roles: EC2 instance roles, Lambda function roles, roles for CloudFormation.

## In my own words
IAM decides who can do what in my AWS account, and it applies across every region. People get users, users go into groups, and a group's policy applies to everyone in it. A policy is JSON that allows or denies actions on resources. If anything explicitly denies an action, it's denied, and if nothing allows it, it's denied too. Root shouldn't be used day to day, so it has MFA and I work as an IAM admin user.

## Still unclear
- [ ] Read the IAM policy evaluation doc page for reference an important material when reviewing

## Shipped
|          |                                                                       |
| -------- | --------------------------------------------------------------------- |
| Artifact | Repo skeleton, `scripts/nightly-check.sh`, `notes/days/day-01-iam.md` |
| Commit   | `docs(notes): day 1 IAM notes and obsidian setup`                     |
| Post     | Sprint announcement                                                   |

## Tomorrow's first tiny task
Write 10.0.0.0/16 on paper and split it into four /24 subnets.
