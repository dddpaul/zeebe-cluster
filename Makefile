CLUSTER=camunda-platform
ZEEBE_NAME=zeebe
PROM_NAME=prom

cluster:
	@kind create cluster --name ${CLUSTER}
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

helm:
	@helm repo add camunda https://helm.camunda.io
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update

install: helm
	@helm install ${ZEEBE_NAME} camunda/camunda-platform -f camunda-platform-core-kind-values.yaml
	@helm install ${PROM_NAME} prometheus-community/kube-prometheus-stack

uninstall:
	@helm uninstall ${ZEEBE_NAME}
	@helm uninstall ${PROM_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

forward:
	kubectl port-forward svc/dev-operate 8081:80 --address 0.0.0.0 & \
	kubectl port-forward svc/dev-zeebe-gateway 26500:26500 --address 0.0.0.0 \
	kubectl port-forward svc/dev-zeebe-gateway 26500:26500 --address 0.0.0.0 \
