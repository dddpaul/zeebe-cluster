CLUSTER=camunda-platform
HELM_CAMUNDA_NAME=camunda
HELM_METRICS_NAME=metrics

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-config.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

load: cluster
	@docker pull docker.elastic.co/elasticsearch/elasticsearch:7.17.3
	@kind load docker-image docker.elastic.co/elasticsearch/elasticsearch:7.17.3 --name ${CLUSTER}

helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add camunda https://helm.camunda.io
	@helm repo update

install: helm
	@helm install ${HELM_METRICS_NAME} prometheus-community/kube-prometheus-stack
	@helm install ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-platform-core-kind-values.yaml
	@kubectl patch service camunda-zeebe-gateway --patch-file zeebe-gateway-jmx-patch.yaml
	@kubectl apply -f zeebe-nodeports.yaml

install-camunda:
	@helm install ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-platform-core-kind-values.yaml
	@kubectl patch service camunda-zeebe-gateway --patch-file zeebe-gateway-jmx-patch.yaml
	@kubectl apply -f zeebe-nodeports.yaml
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-0 --timeout=60s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-1 --timeout=60s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-2 --timeout=60s
	@kubectl wait --namespace default --for=condition=ready pod --selector=app.kubernetes.io/name=zeebe-gateway --timeout=60s
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

uninstall:
	@helm uninstall ${HELM_METRICS_NAME}
	@helm uninstall ${HELM_CAMUNDA_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

rebalance:
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh
