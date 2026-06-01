#!/bin/bash

# Alert for failed jobs
FAILED_JOBS=$(curl -s http://localhost:9090/api/v1/query?query=jenkins_job_last_build_result{result=\"FAILURE\"} | jq '.data.result[].metric.job_name')

if [ ! -z "$FAILED_JOBS" ]; then
    echo "Alert: Failed Jenkins jobs found:"
    echo "$FAILED_JOBS"
fi

# Job health summary
TOTAL_JOBS=$(curl -s http://localhost:9090/api/v1/query?query=count(jenkins_job_last_build_result) | jq '.data.result[0].value[1]')
echo "Total monitored jobs: $TOTAL_JOBS"
