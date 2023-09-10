CLUSTER=camunda
HELM_CAMUNDA_NAME=camunda
HELM_KIBANA_NAME=kibana
HELM_METRICS_NAME=metrics

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-config.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml

# worker7 runs kibana, worker7-9 run elasticsearch
load:
	@docker pull docker.elastic.co/elasticsearch/elasticsearch:7.17.11
	@docker pull docker.elastic.co/kibana/kibana:7.17.11
	@kind load docker-image docker.elastic.co/elasticsearch/elasticsearch:7.17.11 --name ${CLUSTER} --nodes ${CLUSTER}-worker7,${CLUSTER}-worker8,${CLUSTER}-worker9
	@kind load docker-image docker.elastic.co/kibana/kibana:7.17.11 --name ${CLUSTER} --nodes ${CLUSTER}-worker7

helm:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add camunda https://helm.camunda.io
	@helm repo update

install-metrics:
	@helm upgrade -i ${HELM_METRICS_NAME} prometheus-community/kube-prometheus-stack -f prometheus-kind-values.yaml

install-camunda:
	@helm upgrade -i ${HELM_CAMUNDA_NAME} camunda/camunda-platform -f camunda-kind-values.yaml
	@kubectl patch service camunda-zeebe-gateway --patch-file zeebe-gateway-jmx-patch.yaml
	@kubectl apply -f zeebe-nodeports.yaml
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-0 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-1 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=statefulset.kubernetes.io/pod-name=camunda-zeebe-2 --timeout=300s
	@kubectl wait --namespace default --for=condition=ready pod --selector=app.kubernetes.io/name=zeebe-gateway --timeout=300s
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

install-kibana:
	@helm upgrade -i ${HELM_KIBANA_NAME} ./helm-charts/elastic/kibana -f kibana-kind-values.yml

install: helm install-metrics install-camunda install-kibana

uninstall:
	@helm uninstall ${HELM_METRICS_NAME}
	@helm uninstall ${HELM_CAMUNDA_NAME}
	@helm uninstall ${HELM_KIBANA_NAME}

destroy:
	@kind delete cluster --name ${CLUSTER}

rebalance:
	@curl -X POST http://127.0.0.1:9600/actuator/rebalance

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh
