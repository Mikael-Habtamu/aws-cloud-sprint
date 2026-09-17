#!/usr/bin/env bash
# Sets up the Obsidian vault structure inside the aws-cloud-sprint repo.
# Run from the repo root:  bash ~/Downloads/setup-obsidian.sh
# Safe to re-run: never overwrites a file that already exists.

set -e

# Stop if not in the repo root
[ -d .git ] || { echo "Run this from ~/projects/aws-cloud-sprint (the repo root)."; exit 1; }

# --- Folders -------------------------------------------------------------
mkdir -p notes/days notes/reviews notes/exam notes/templates \
         labs adr \
         docs/assets docs/diagrams docs/writeups docs/postmortems \
         docs/runbooks docs/cost-optimisation docs/interview \
         private

# Helper: write stdin to a file only if the file doesn't exist yet
write_new() {
  if [ -e "$1" ]; then
    echo "skip (exists): $1"
    cat > /dev/null
  else
    cat > "$1"
    echo "created: $1"
  fi
}

# --- Move the Day 1 note into notes/days/ if it's at the old path --------
if [ -f notes/day-01-iam.md ] && [ ! -e notes/days/day-01-iam.md ]; then
  if git ls-files --error-unmatch notes/day-01-iam.md > /dev/null 2>&1; then
    git mv notes/day-01-iam.md notes/days/day-01-iam.md
  else
    mv notes/day-01-iam.md notes/days/day-01-iam.md
  fi
  echo "moved: notes/day-01-iam.md -> notes/days/"
fi

# --- Templates -----------------------------------------------------------
write_new notes/templates/day.md <<'EOF'
---
date: {{date}}
sprint-day:
topic:
---
# {{title}}

## What I did

## Commands I ran

## What broke and why

## In my own words

## What I still don't get

## Artifact, commit, publish
- Artifact:
- Commit:
- Posted:
EOF

write_new notes/templates/adr.md <<'EOF'
# ADR-NNN: Title

- Status: Accepted
- Date: {{date}}

## Context
What problem, what constraints.

## Decision
What I chose.

## Alternatives considered
What else, and why not.

## Consequences
What this costs me, what it makes easier, what it makes harder.
EOF

write_new notes/templates/postmortem.md <<'EOF'
# Postmortem: Title

- Date: {{date}}
- Severity:
- Status: Resolved

## Summary

## Impact

## Detection
How I found out, and how long it took.

## Timeline (UTC+3)
| Time | Event |
|------|-------|
|      |       |

## Root cause

## Resolution

## Prevention items
| Item | Owner | Status |
|------|-------|--------|
|      | Mikael |       |
EOF

write_new notes/templates/weekly-review.md <<'EOF'
# Week N review

- Date: {{date}}
- Mock score:

## Done

## Slipped

## Cut

## Stop condition
(Day 14 only: what I do if Day 21 arrives with Project 2 half-built.)

## Next week
EOF

# --- Exam files ----------------------------------------------------------
write_new notes/exam/wrong-answers.md <<'EOF'
# Wrong answers

| Date | Topic | My answer | Correct | Rule I missed |
|------|-------|-----------|---------|---------------|
EOF

write_new notes/exam/mock-scores.md <<'EOF'
# Mock scores

| Date | Mock | Score | Weakest domains |
|------|------|-------|-----------------|
EOF

write_new notes/exam/comparison-tables.md <<'EOF'
# Comparison tables

## SQS vs SNS vs EventBridge

## ALB vs NLB vs Gateway LB

## Security groups vs NACLs

## EBS volume types

## S3 storage classes

## RDS Multi-AZ vs read replicas

## RDS vs DynamoDB

## CloudTrail vs CloudWatch vs Config
EOF

# --- Private (gitignored) ------------------------------------------------
write_new private/outreach-tracker.md <<'EOF'
# Outreach tracker

| Company | Role | Date | Channel | Contact | Status | Follow-up |
|---------|------|------|---------|---------|--------|-----------|
EOF

# --- Home note -----------------------------------------------------------
write_new notes/00-home.md <<'EOF'
# AWS sprint home

- Sprint: 15 Sept to 14 Oct 2026
- Exam: SAA-C03, 30 Sept 2026, 8:30 AM, IE Network Solutions
- Region: eu-north-1 (ACM certificates for CloudFront: us-east-1)

## Exam
- [Wrong answers](exam/wrong-answers.md)
- [Mock scores](exam/mock-scores.md)
- [Comparison tables](exam/comparison-tables.md)

## Days
- [Day 1: IAM](days/day-01-iam.md)

## Reviews

## Decisions
See [adr/](../adr/)
EOF

# --- .gitignore ----------------------------------------------------------
touch .gitignore
# make sure the file ends with a newline before appending
[ -n "$(tail -c1 .gitignore)" ] && echo >> .gitignore
for line in ".obsidian/" ".trash/" "private/"; do
  grep -qxF "$line" .gitignore || { echo "$line" >> .gitignore; echo "gitignore: added $line"; }
done

echo
echo "Done. Now check that private/ is ignored:"
echo "  git check-ignore -v private/outreach-tracker.md"
