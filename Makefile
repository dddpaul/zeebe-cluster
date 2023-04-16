CLUSTER=camunda-platform

cluster:
	@kind create cluster --name ${CLUSTER}
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

destroy:
	@kind delete cluster --name ${CLUSTER}
