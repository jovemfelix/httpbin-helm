# Setup
> variables
```shell
NS=httpbin-v2
CTRL_PLANE_NS=istio-system
SECRET=httpbin-v2
INGRESS_PORT=80
SECURE_INGRESS_PORT=443
MY_HOST=teste.com
INGRESS_HOST=$(oc get pod -l app=vsphere-infra-vrrp -o yaml -n openshift-vsphere-infra | grep -i '\-\-ingress-vip' -A1 | grep -v '\-\-ingress-vip\|--' | uniq | awk '{print $2}')
```

> create namespace
```shell
$ oc new-project $NS
```

# Manual Execution
> Example using template and openshift apply
```shell
$ helm template . --set gateway.hosts=$MY_HOST  --name-template v1 --output-dir target
$ oc apply -f target\httpbin\templates

# or
$ helm template . --set gateway.hosts=$MY_HOST --name-template v1 | oc apply -f -

```

# disable route generation
```shell
oc -n istio-system get servicemeshcontrolplanes.maistra.io basic -o yaml
oc -n istio-system edit servicemeshcontrolplanes.maistra.io basic
```

```yaml
  gateways:
    openshiftRoute:
      enabled: false
```

# habilitar mesmo host any project
```shell
oc -n openshift-ingress-operator get ingresscontroller/default -o yaml | bat -l yaml
oc -n openshift-ingress-operator patch ingresscontroller/default --patch '{"spec":{"routeAdmission":{"namespaceOwnership":"InterNamespaceAllowed"}}}' --type=merge
```

# Helpers
```shell
oc get route -n ${CTRL_PLANE_NS}
# teste http
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/status/418"
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/status/200"
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/delay/2"

curl -s -I -HHost:$MY_HOST "http://$INGRESS_HOST:$INGRESS_PORT/status/200"

curl -H "Host: $MY_HOST" --resolve "$MY_HOST:443:$INGRESS_HOST" "https://$MY_HOST:$SECURE_INGRESS_PORT/status/418"
  
```
# Testing with Route

```shell
# remove gw and vs and restart de Pods
oc delete gw,vw,pod --all -n $NS
# 
curl -sH "Host: $MY_HOST" --resolve "$MY_HOST:$SECURE_INGRESS_PORT:$INGRESS_HOST" "https://$MY_HOST:$SECURE_INGRESS_PORT/status/418" -k
```