The problem is broken Basic authentication in Operate UI when old zeebe exporter is enabled.

camunda-zeebe (orchestration) with new camunda exporter application.yml:
```
zeebe:
  broker:
   exporters:
      camundaexporter:
        className: "io.camunda.exporter.CamundaExporter"
        args:
          connect:
            type: "elasticsearch"
            url: "http://camunda-elasticsearch:9200"
            awsEnabled: false
          history:
            elsRolloverDateFormat: "date"
            rolloverInterval: "1d"
            rolloverBatchSize: 100
            waitPeriodBeforeArchiving: "1h"
            delayBetweenRuns: 2000
            maxDelayBetweenRuns: 60000
```

camunda-zeebe (orchestration) with old zeebe exporter application.yml:
```
zeebe:
  broker:
    exporters:
      elasticsearch:
        className: "io.camunda.zeebe.exporter.ElasticsearchExporter"
        args:
          url: "http://camunda-elasticsearch:9200"
          index:
            prefix: "zeebe-record"
            numberOfReplicas: "1"
```


data configuration with new camunda exporter in application.yml:
```
camunda:
  data:
    snapshot-period: "5m"
    primary-storage:
      disk:
        free-space:
          processing: "2GB"
          replication: "1GB"
    secondary-storage:
      autoconfigure-camunda-exporter: true
      type: "elasticsearch"
      elasticsearch:
        url: "http://camunda-elasticsearch:9200"
        cluster-name: "elasticsearch"
        username: ""
        password: "${VALUES_ELASTICSEARCH_PASSWORD:}"
        index-prefix: ""
```

data configuration with old zeebe exporter in application.yml:
```
camunda:
  data:
    snapshot-period: "5m"
    primary-storage:
      disk:
        free-space:
          processing: "2GB"
          replication: "1GB"
    secondary-storage:
      autoconfigure-camunda-exporter: false
      type: "elasticsearch"
      elasticsearch:
        url: "http://camunda-elasticsearch:9200"
        cluster-name: "elasticsearch"
        username: ""
        password: "${VALUES_ELASTICSEARCH_PASSWORD:}"
        index-prefix: ""
```

the common block:
```
camunda:
  security:
    authentication:
      method: "basic"
      unprotectedApi: true
    authorizations:
      enabled: false
    initialization:
      default-roles:
        admin:
          mappingRules: []
          users:
          - demo
        connectors:
          clients:
          - connectors
          mappingRules: []
          users:
          - connectors
      users:
        - email: connector@demo.com
          name: Connector User
          password: connector
          username: connectors
        - email: demo@demo.com
          name: Demo User
          password: demo
          username: demo
    multiTenancy:
      checksEnabled: false
      apiEnabled: true
```

With camunda exporter there are working Basic authentication to Operate UI, it's seen by debug logging:
```
DEBUG io.camunda.authentication.DefaultCamundaAuthenticationProvider - Created camunda authentication: CamundaAuthentication[authenticatedUsername=demo,
 authenticatedClientId=null, authenticatedGroupIds=[], authenticatedRoleIds=[admin], authenticatedTenantIds=[<default>], authenticatedMappingRuleIds=[], claims=null]
```

With old zeebe exporter DefaultCamundaAuthenticationProvider is not initialized by some reason. You should find this reason.
Examine and use unit and integration tests for it.
