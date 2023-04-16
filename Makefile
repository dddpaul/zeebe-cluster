CLUSTER=camunda-platform
NAME=dev

cluster:
	@kind create cluster --name ${CLUSTER}
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

helm:
	@helm repo add camunda https://helm.camunda.io
	@helm repo update

camunda: helm
	@helm install ${NAME} camunda/camunda-platform -f camunda-platform-core-kind-values.yaml

destroy:
	@kind delete cluster --name ${CLUSTER}
