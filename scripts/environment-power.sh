#!/usr/bin/env bash
# Pauses or resumes the whole project (both environments and the shared database) to save costs.
set -euo pipefail

usage() {
  echo "usage: $0 pause|resume|status" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
action=$1
region=${AWS_REGION:-us-east-1}
prefix=silver-proposals
db=$prefix
environments=(staging prod)

aws_() { aws --region "$region" "$@"; }

alarms() {
  aws_ cloudwatch describe-alarms --alarm-name-prefix "$prefix-" --query 'MetricAlarms[].AlarmName' --output text
}

scale() {
  local count=$1 env
  for env in "${environments[@]}"; do
    aws_ ecs update-service --cluster "$prefix-$env" --service api --desired-count "$count" \
      --query 'service.[serviceName,desiredCount]' --output text >/dev/null
    echo "ecs $prefix-$env/api: desired $count"
  done
  for env in "${environments[@]}"; do
    aws_ ecs wait services-stable --cluster "$prefix-$env" --services api
  done
}

db_status() {
  aws_ rds describe-db-instances --db-instance-identifier "$db" --query 'DBInstances[0].DBInstanceStatus' --output text
}

case $action in
  status)
    echo "database $db: $(db_status)"
    for env in "${environments[@]}"; do
      aws_ ecs describe-services --cluster "$prefix-$env" --services api \
        --query "services[0].['$prefix-$env/api', desiredCount, runningCount]" --output text |
        awk '{ print "ecs " $1 ": desired " $2 ", running " $3 }'
    done
    aws_ cloudwatch describe-alarms --alarm-name-prefix "$prefix-" \
      --query 'MetricAlarms[].[AlarmName, StateValue, ActionsEnabled]' --output text |
      awk '{ print "alarm " $1 ": " $2 ", actions " ($3 == "True" ? "on" : "off") }'
    ;;
  pause)
    # Silence notifications first: stopping the services makes the health alarms fire.
    # shellcheck disable=SC2046
    aws_ cloudwatch disable-alarm-actions --alarm-names $(alarms)
    echo "alarm actions: off"
    scale 0
    if [[ $(db_status) == available ]]; then
      aws_ rds stop-db-instance --db-instance-identifier "$db" >/dev/null
      echo "database $db: stopping (AWS starts it again by itself after 7 days)"
    fi
    echo "paused; the load balancer keeps running and billing"
    ;;
  resume)
    if [[ $(db_status) == stopped ]]; then
      aws_ rds start-db-instance --db-instance-identifier "$db" >/dev/null
      echo "database $db: starting"
    fi
    aws_ rds wait db-instance-available --db-instance-identifier "$db"
    echo "database $db: available"
    scale 1
    for env in "${environments[@]}"; do
      host=api-$env.silversoft.com.br
      [[ $env == prod ]] && host=api.silversoft.com.br
      curl -fsS --retry 5 --retry-all-errors --retry-delay 10 "https://$host/ready" >/dev/null
      echo "https://$host/ready: ok"
    done
    # Let the alarms see healthy data before notifications come back on.
    sleep 360
    # shellcheck disable=SC2046
    aws_ cloudwatch enable-alarm-actions --alarm-names $(alarms)
    echo "alarm actions: on"
    ;;
  *) usage ;;
esac
