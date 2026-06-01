import jenkins.model.*
import jenkins.plugins.prometheus.*
import hudson.util.*;

// Set Prometheus configuration
def prometheusConfig = JenkinsPrometheusConfiguration.get()
prometheusConfig.setPath("/prometheus")
prometheusConfig.setCollectBuildMetrics(true)
prometheusConfig.setJobAttributeName("jenkins_job")
prometheusConfig.save()

println "Prometheus plugin configured"

// Create job metric collector
def jobs = Jenkins.instance.getAllItems(hudson.model.Job)
println "Total jobs found: ${jobs.size()}"

jobs.each { job ->
    println "Job: ${job.fullName} - Last build: ${job.lastBuild?.result}"
}
