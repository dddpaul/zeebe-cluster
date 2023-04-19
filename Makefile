CLUSTER=camunda-platform
HELM_CAMUNDA_NAME=camunda
HELM_METRICS_NAME=metrics

cluster:
	@kind create cluster --name ${CLUSTER}
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

uninstall:
	@helm uninstall ${HELM_METRICS_NAME}
	@helm uninstall ${HELM_CAMUNDA_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

forward:
	kubectl port-forward svc/${HELM_CAMUNDA_NAME}-operate 8081:80 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_CAMUNDA_NAME}-zeebe-gateway 26500:26500 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_METRICS_NAME}-grafana 8082:80 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_METRICS_NAME}-kube-prometheus-stack-prometheus 9090:9090 --address 0.0.0.0
