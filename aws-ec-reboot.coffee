AWS = require 'aws-sdk'
config = require './config.json'
###
config.json "schema" needs to be as per the following example:
{ 
  "credentials": { "region": "ap-southeast-2", "accessKeyId": "", "secretAccessKey": "" },
  "applications": [ { "ApplicationName": "" } ],
  "cacheEnvironmentVariableName": "REDIS_HOST"
}
###

AWS.config.region = config.credentials.region
AWS.config.accessKeyId = config.credentials.accessKeyId
AWS.config.secretAccessKey = config.credentials.secretAccessKey

elasticbeanstalk = new AWS.ElasticBeanstalk
for application in config.applications
    console.log "About to reboot cache for application: #{application.ApplicationName} ..."
    elasticbeanstalk.describeEnvironments application, (err, response) =>
        console.log err, err.stack if err?
        if response?
            for environment in response.Environments
                console.log "About to reboot cache for environment: #{environment.EnvironmentName} ..."
                elasticbeanstalk.describeConfigurationSettings { ApplicationName: environment.ApplicationName, EnvironmentName: environment.EnvironmentName }, (err, response) =>
                    console.log err, err.stack if err?
                    if response? && response.ConfigurationSettings.length > 0
                        cacheEnvironmentVariableNameUpperCase = config.cacheEnvironmentVariableName.toUpperCase()
                        for environmentVariable in response.ConfigurationSettings[0].OptionSettings
                            if environmentVariable.Namespace.toLowerCase() == 'aws:elasticbeanstalk:application:environment' && environmentVariable.OptionName.toUpperCase() == cacheEnvironmentVariableNameUpperCase
                                redisHost = environmentVariable.Value 
                                firstDotIndex = redisHost.indexOf('.')
                                if firstDotIndex > -1
                                    redisHost = redisHost.substring(0, firstDotIndex)
                                elasticache = new AWS.ElastiCache                                    
                                elasticache.describeCacheClusters { CacheClusterId: redisHost, ShowCacheNodeInfo: true }, (err, response) =>
                                    console.log err, err.stack if err?
                                    if response? && response.CacheClusters.length > 0
                                        redisHost = response.CacheClusters[0].CacheClusterId
                                        cacheNodes = []
                                        cacheNodes.push(node.CacheNodeId) for node in response.CacheClusters[0].CacheNodes
                                        console.log "About to reboot cache nodes for cluster: #{redisHost} ..."
                                        elasticache.rebootCacheCluster { CacheClusterId: redisHost, CacheNodeIdsToReboot: cacheNodes }, (err, response) =>
                                            console.log err, err.stack if err?
                                            console.log response if response?