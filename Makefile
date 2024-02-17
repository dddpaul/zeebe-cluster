CLUSTER=camunda
HELM_CAMUNDA_NAME=camunda
HELM_METRICS_NAME=metrics

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-config.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

# worker2 runs gateway, worker3-5 run brokers, worker6 runs operate
load-zeebe:
	@docker pull camunda/zeebe:8.4.3
	@kind load docker-image camunda/zeebe:8.4.3 --name ${CLUSTER} --nodes ${CLUSTER}-worker2,${CLUSTER}-worker3,${CLUSTER}-worker4,${CLUSTER}-worker5
	@docker pull camunda/operate:8.4.3
	@kind load docker-image camunda/operate:8.4.3 --name ${CLUSTER} --nodes ${CLUSTER}-worker6

# worker7 runs kibana, worker7-9 run elasticsearch
load-es:
	@docker pull bitnami/elasticsearch:8.9.2
	@docker pull bitnami/kibana:8.9.2
	@kind load docker-image bitnami/elasticsearch:8.9.2 --name ${CLUSTER} --nodes ${CLUSTER}-worker7,${CLUSTER}-worker8,${CLUSTER}-worker9
	@kind load docker-image bitnami/kibana:8.9.2 --name ${CLUSTER} --nodes ${CLUSTER}-worker7

# worker10 runs connectors
load-connectors:
	@docker pull camunda/connectors-bundle:8.4.3
	@kind load docker-image camunda/connectors-bundle:8.4.3 --name ${CLUSTER} --nodes ${CLUSTER}-worker10

load: load-zeebe load-es load-connectors

helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add camunda https://helm.camunda.io
	@helm repo update

install-metrics:
	@helm upgrade -i ${HELM_METRICS_NAME} prometheus-community/kube-prometheus-stack -f prometheus-kind-values.yaml

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
	@helm upgrade -i ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-kind-values.yaml --version 9.1.0
	@kubectl patch service camunda-zeebe-gateway --patch-file zeebe-gateway-jmx-patch.yaml
	@kubectl apply -f zeebe-nodeports.yaml
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-0 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-1 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-2 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=app.kubernetes.io/name=zeebe-gateway --timeout=300s
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

install: helm install-metrics install-camunda

uninstall:
	@helm uninstall ${HELM_METRICS_NAME}
	@helm uninstall ${HELM_CAMUNDA_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

rebalance:
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh
