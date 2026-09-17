#!/usr/bin/env bash
# nightly-check.sh - end-of-day sweep for billable AWS resources left running.
# Usage: bash scripts/nightly-check.sh
# Optional: AWS_PROFILE=name  REGIONS="eu-central-1 us-east-1"
set -uo pipefail

PROFILE="${AWS_PROFILE:-default}"
DEFAULT_REGION="$(aws configure get region --profile "$PROFILE" 2>/dev/null)"
REGIONS="${REGIONS:-$DEFAULT_REGION us-east-1}"
found=0

check() {
  local label="$1"; shift
  local out
  out=$("$@" --profile "$PROFILE" --output text 2>&1)
  if [ -z "$out" ] || [ "$out" = "None" ]; then
    echo "  OK     $label: none"
  else
    echo "  FOUND  $label:"
    echo "$out" | sed 's/^/           /'
    found=1
  fi
}

echo "== Identity =="
aws sts get-caller-identity --profile "$PROFILE" --query Arn --output text \
  || { echo "AWS CLI not configured for profile '$PROFILE'"; exit 1; }

for r in $REGIONS; do
  echo
  echo "== Region: $r =="
  check "EC2 instances (running/stopped)" aws ec2 describe-instances --region "$r" \
    --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]'
  check "NAT gateways" aws ec2 describe-nat-gateways --region "$r" \
    --filter Name=state,Values=pending,available \
    --query 'NatGateways[].[NatGatewayId,VpcId,State]'
  check "Elastic IPs" aws ec2 describe-addresses --region "$r" \
    --query 'Addresses[].[PublicIp,AllocationId,AssociationId]'
  check "Unattached EBS volumes" aws ec2 describe-volumes --region "$r" \
    --filters Name=status,Values=available \
    --query 'Volumes[].[VolumeId,Size]'
  check "Load balancers" aws elbv2 describe-load-balancers --region "$r" \
    --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code]'
  check "RDS instances" aws rds describe-db-instances --region "$r" \
    --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]'
  check "EKS clusters" aws eks list-clusters --region "$r" \
    --query 'clusters[]'
done

echo
echo "== Month-to-date cost =="
start="$(date +%Y-%m-01)"
end="$(date -d tomorrow +%F)"
aws ce get-cost-and-usage --region us-east-1 --profile "$PROFILE" \
  --time-period Start="$start",End="$end" --granularity MONTHLY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost.[Amount,Unit]' --output text \
  || echo "  Cost Explorer unavailable (not enabled yet, or no permission)"

echo
if [ "$found" -eq 1 ]; then
  echo "RESULT: billable resources found. Delete or destroy what you're not using."
else
  echo "RESULT: clean."
fi
