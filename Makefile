CLUSTER=camunda
HELM_CAMUNDA_NAME=camunda
HELM_METRICS_NAME=metrics

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-config.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

# worker2 runs gateway, worker3-5 run brokers, worker6 runs operate
load-zeebe:
	@docker pull aivinog1/zeebe:8.2.15-add-async-pool-for-channel
	@kind load docker-image aivinog1/zeebe:8.2.15-add-async-pool-for-channel --name ${CLUSTER} --nodes ${CLUSTER}-worker2
	@kind load docker-image aivinog1/zeebe:8.2.15-add-async-pool-for-channel --name ${CLUSTER} --nodes ${CLUSTER}-worker3,${CLUSTER}-worker4,${CLUSTER}-worker5

load: load-zeebe

helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add camunda https://helm.camunda.io
	@helm repo update

install-metrics:
	@helm upgrade -i ${HELM_METRICS_NAME} prometheus-community/kube-prometheus-stack -f prometheus-kind-values.yaml

pre-upgrade:
	@kubectl --namespace default delete deployment ${HELM_CAMUNDA_NAME}-operate
	@kubectl --namespace default delete deployment ${HELM_CAMUNDA_NAME}-zeebe-gateway
	@kubectl --namespace default delete statefulset ${HELM_CAMUNDA_NAME}-zeebe

install-camunda:
	@helm upgrade -i ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-kind-values.yaml --version 8.3.3
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
