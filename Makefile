CLUSTER=camunda-platform
HELM_ZEEBE_NAME=zeebe
HELM_PROM_NAME=prom

cluster:
	@kind create cluster --name ${CLUSTER}
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

load: cluster
	@docker pull docker.elastic.co/elasticsearch/elasticsearch:7.17.3
	@kind load docker-image docker.elastic.co/elasticsearch/elasticsearch:7.17.3 --name ${CLUSTER}

helm:
	@helm repo add camunda https://helm.camunda.io
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update

install: helm
	@helm install ${HELM_ZEEBE_NAME} camunda/camunda-platform -f camunda-platform-core-kind-values.yaml
	@helm install ${HELM_PROM_NAME} prometheus-community/kube-prometheus-stack

uninstall:
	@helm uninstall ${HELM_ZEEBE_NAME}
	@helm uninstall ${HELM_PROM_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

forward:
	kubectl port-forward svc/${HELM_ZEEBE_NAME}-operate 8081:80 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_ZEEBE_NAME}-zeebe-gateway 26500:26500 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_PROM_NAME}-grafana 8082:80 --address 0.0.0.0 & \
	kubectl port-forward svc/${HELM_PROM_NAME}-kube-prometheus-stack-prometheus 9090:9090 --address 0.0.0.0
