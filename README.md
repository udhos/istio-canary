# istio-canary

## Before starting

```
kind version
kind v0.20.0 go1.20.4 linux/amd64

helm version
version.BuildInfo{Version:"v3.13.3", GitCommit:"c8b948945e52abba22ff885446a1486cb5fd3474", GitTreeState:"clean", GoVersion:"go1.20.11"}
```

## istio

```
kind create cluster --name lab

helm repo add istio https://istio-release.storage.googleapis.com/charts

helm repo update

kubectl create ns istio-system

helm upgrade istio-base istio/base -n istio-system --install

helm upgrade istiod istio/istiod -n istio-system --install

helm list -A
NAME      	NAMESPACE   	REVISION	UPDATED                                	STATUS  	CHART        	APP VERSION
istio-base	istio-system	1       	2024-02-22 19:19:21.779586644 -0300 -03	deployed	base-1.20.3  	1.20.3     
istiod    	istio-system	1       	2024-02-22 19:19:28.714069744 -0300 -03	deployed	istiod-1.20.3	1.20.3     
```

## services

```
kubectl create ns develop

kubectl label ns develop istio-injection=enabled

helm upgrade -n develop --install pismo-egress miniapi/miniapi --values values-miniapi-pismo-egress.yaml

helm upgrade -n develop --install npc-regress-pismo miniapi/miniapi --values values-miniapi-npc-regress-pismo.yaml
```

## Canary

```
./canary.sh develop pismo-egress 3000 3000 pismo-egress npc-regress-pismo 50
```

## Clean-up

```
kind delete cluster --name lab
```