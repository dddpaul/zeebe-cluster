CLUSTER=camunda
HELM_CAMUNDA_NAME=camunda
HELM_METRICS_NAME=metrics
HELM_REDIS_NAME=redis
HELM_INGRESS_NAME=ingress

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-config.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml
	@kubectl apply -f zeebe-nodeports.yaml

# grafana/prometeheus runs on worker, node-exporter runs on all nodes
load-metrics:
	@docker pull docker.io/grafana/grafana:12.0.0
	@kind load docker-image docker.io/grafana/grafana:12.0.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker &
	@docker pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0
	@kind load docker-image registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker &
	@docker pull quay.io/prometheus/node-exporter:v1.9.1
	@kind load docker-image quay.io/prometheus/node-exporter:v1.9.1 --name ${CLUSTER}

# worker11 runs redis / keydb
load-redis:
	@docker pull eqalpha/keydb:x86_64_v6.3.4
	@kind load docker-image eqalpha/keydb:x86_64_v6.3.4 --name ${CLUSTER} --nodes ${CLUSTER}-worker11

# worker2 runs gateway, worker3-5 run brokers, worker6 runs operate
load-zeebe:
	@docker pull camunda/camunda:8.8.8
	@kind load docker-image camunda/camunda:8.8.8 --name ${CLUSTER} --nodes ${CLUSTER}-worker2,${CLUSTER}-worker3,${CLUSTER}-worker4,${CLUSTER}-worker5 &
	@docker pull camunda/operate:8.6.14
	@kind load docker-image camunda/operate:8.6.14 --name ${CLUSTER} --nodes ${CLUSTER}-worker6

# worker7 runs kibana, worker7-9 run elasticsearch
load-es:
	@docker pull bitnamilegacy/elasticsearch:8.18.0
	@docker pull bitnamilegacy/kibana:8.18.0
	@kind load docker-image bitnamilegacy/elasticsearch:8.18.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker7,${CLUSTER}-worker8,${CLUSTER}-worker9 &
	@kind load docker-image bitnamilegacy/kibana:8.18.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker7

# worker10 runs connectors
load-connectors:
	@docker pull camunda/connectors-bundle:8.8.2
	@kind load docker-image camunda/connectors-bundle:8.5.2 --name ${CLUSTER} --nodes ${CLUSTER}-worker10

load: load-metrics load-redis load-zeebe load-es load-connectors

helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add camunda https://helm.camunda.io
	@helm repo add enapter https://enapter.github.io/charts/
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	@helm repo update

install-metrics:
#	@helm upgrade -i ${HELM_METRICS_NAME} prometheus-community/kube-prometheus-stack -f prometheus-kind-values.yaml
	@helm upgrade -i ${HELM_METRICS_NAME} ./helm-charts/kube-prometheus-stack-72.3.0.tgz -f prometheus-kind-values.yaml

install-ingress:
	@helm upgrade -i ${HELM_INGRESS_NAME} ingress-nginx/ingress-nginx -f ingress-nginx-values.yaml \
	--namespace ingress-nginx \
    --create-namespace

install-redis:
	@helm upgrade -i ${HELM_REDIS_NAME} enapter/keydb -f keydb-kind-values.yaml

pre-upgrade-zeebe:
	@kubectl --namespace default delete deployment ${HELM_CAMUNDA_NAME}-operate
	@kubectl --namespace default delete deployment ${HELM_CAMUNDA_NAME}-zeebe-gateway
	@kubectl --namespace default delete statefulset ${HELM_CAMUNDA_NAME}-zeebe

pre-upgrade-es:
	@kubectl scale statefulset elasticsearch-master --replicas=0
	@kubectl delete statefulset elasticsearch-master
	@./pre-upgrade-es.sh

pre-upgrade: pre-upgrade-zeebe pre-upgrade-es
	@helm uninstall kibana

install-camunda:
#	@helm upgrade -i ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-kind-values.yaml --version 11.3.1
	@helm upgrade -i ${HELM_CAMUNDA_NAME} ./helm-charts/camunda-platform-13.3.2-1.tgz -f camunda-kind-values.yaml
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-0 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-1 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-2 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=app.kubernetes.io/name=zeebe-gateway --timeout=300s
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

install: helm install-metrics install-redis install-camunda

uninstall:
	@helm uninstall ${HELM_METRICS_NAME}
	@helm uninstall ${HELM_CAMUNDA_NAME}
	@helm uninstall ${HELM_REDIS_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

rebalance:
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

flowcontrol:
	@curl -X POST -H "Content-Type: application/json" -d "@flow-control.json" http://127.0.0.1:9600/actuator/flowControl
	@curl -X POST -H "Content-Type: application/json" -d '{"configuredLevel":"debug"}' http://localhost:9600/actuator/loggers/io.camunda.zeebe.logstreams.impl.flowcontrol

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

operate-log:
	while true; do stern -l "app.kubernetes.io/component=operate" -o raw -t --color=never --init-containers=false --no-follow -i "batchRequest"; done

resource-capacity:
	kubectl resource-capacity -u -p -n default -l "app.kubernetes.io/instance=camunda" --pod-count
