# Setup
> variables
```shell
export NS=httpbin-shard-v1
export CTRL_PLANE_NS=istio-system
export CTRL_PLANE_DMZ_NS=istio-system-dmz
export ISTIO_SELECTOR=ingressgateway
export ISTIO_SELECTOR_DMZ=shard-dmz-ingressgateway
export SECRET=httpbin-route-tls
export INGRESS_PORT_SECURE=443
export MY_HOST=same.example.com
export INGRESS_HOST=$(oc get pod -l app=vsphere-infra-vrrp -o yaml -n openshift-vsphere-infra | grep -i '\-\-ingress-vip' -A1 | grep -v '\-\-ingress-vip\|--' | uniq | awk '{print $2}')
export INGRESS_HOST_DMZ=10.36.5.100
```

> create namespace with policy
```shell
$ oc new-project $NS
$ oc adm policy add-scc-to-user anyuid -z v1-httpbin -n $NS
```

# Manual Execution
> Example using template and openshift apply
```shell
$ helm template . --set gateway.hosts=${MY_HOST}  --name-template v1 --output-dir target
$ oc apply -f target/httpbin/templates/smm.yaml
$ oc apply -f target\httpbin\templates

# or
$ helm template . --set gateway.hosts=${MY_HOST} --name-template v1 | oc apply -f -

```

# confirm route generation enabled
```shell
oc -n istio-system get servicemeshcontrolplanes.maistra.io basic -o yaml | grep -A 2 'openshiftRoute'
oc -n istio-system edit servicemeshcontrolplanes.maistra.io basic
```

```yaml
  gateways:
    openshiftRoute:
      enabled: true
```

# enable same host at any project
```shell
oc -n openshift-ingress-operator get ingresscontroller/default -o yaml | grep -A 2 'namespaceOwnership'
oc -n openshift-ingress-operator patch ingresscontroller/default --patch '{"spec":{"routeAdmission":{"namespaceOwnership":"InterNamespaceAllowed"}}}' --type=merge
```

# Helpers
```shell
oc get route -n ${CTRL_PLANE_NS}
# teste http
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:80:$INGRESS_HOST" "http://$MY_HOST/status/418"
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:80:$INGRESS_HOST" "http://$MY_HOST/delay/2"

curl -H "Host: $MY_HOST" --resolve "$MY_HOST:443:$INGRESS_HOST" "https://$MY_HOST:$INGRESS_PORT_SECURE/status/418"
  
```

```shell
oc new-project ${CTRL_PLANE_DMZ_NS}

# make shard-dmz namespace a member of the current control plane
oc -n ${CTRL_PLANE_DMZ_NS} apply -f target/httpbin/templates/smm.yaml

# create service in this new namespace
oc -n ${CTRL_PLANE_NS} patch --type=merge smcp/basic -p "spec:
  gateways:
    additionalIngress:
      istio-shard-dmz-ingressgateway:
        enabled: true
        namespace: ${CTRL_PLANE_DMZ_NS}
        runtime:
          deployment:
            autoScaling:
              enabled: true
              maxReplicas: 4
              minReplicas: 2
        service:
          metadata:
            labels:
              app: istio-shard-dmz-ingressgateway
              istio: ${ISTIO_SELECTOR_DMZ}
          type: NodePort"

# view the resources created
$ oc -n $CTRL_PLANE_DMZ_NS get svc,pod -l istio=$ISTIO_SELECTOR_DMZ
NAME                                     TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                      AGE
service/istio-shard-dmz-ingressgateway   NodePort   172.30.137.218   <none>        15021:32345/TCP,80:31141/TCP,443:30021/TCP,15443:31726/TCP   20m

NAME                                                 READY   STATUS    RESTARTS   AGE
pod/istio-shard-dmz-ingressgateway-b95c499fb-2k64n   1/1     Running   0          20m
pod/istio-shard-dmz-ingressgateway-b95c499fb-cjsmv   1/1     Running   0          20m

```

# Enable the Node Placement and Namespace Selector
```shell
# list ingress controllers
$ oc get ingresscontroller -n openshift-ingress-operator
NAME           AGE
default        95d
router-shard   27d

# check nodePlacement
$ oc get ingresscontroller router-shard -n openshift-ingress-operator -o yaml | grep -A 5 'nodePlacement'
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
        type: infra-shard
  replicas: 2

# set the label into control plane for shard of DMZ
$ oc label ns ${CTRL_PLANE_DMZ_NS} type=infra-shard
namespace/istio-system-dmz labeled
```

# View Service Mesh Before
```shell
$ oc -n $NS get gw,vs
NAME                                        AGE
gateway.networking.istio.io/v1-httpbin-gw   16h

NAME                                               GATEWAYS            HOSTS                  AGE
virtualservice.networking.istio.io/v1-httpbin-vs   ["v1-httpbin-gw"]   ["same.example.com"]   16h
```

# Create Gateway and Virtual Service for shard DMZ
```shell
$ helm template . \
--set gateway.hosts=${MY_HOST} \
--set gateway.name=v1-httpbin-dmz-gw  \
--set gateway.selector.istio=${ISTIO_SELECTOR_DMZ}  \
--set vitualService.name=v1-httpbin-dmz-vs  \
--name-template v1 --output-dir target
$ oc -n $NS apply -f target/httpbin/templates/gateway.yaml
$ oc -n $NS apply -f target/httpbin/templates/virtualservice.yaml
```

# View Service Mesh After
```shell
$ oc -n $NS get gw,vs
NAME                                            AGE
gateway.networking.istio.io/v1-httpbin-dmz-gw   32s
gateway.networking.istio.io/v1-httpbin-gw       16h

NAME                                                   GATEWAYS                HOSTS                  AGE
virtualservice.networking.istio.io/v1-httpbin-dmz-vs   ["v1-httpbin-dmz-gw"]   ["same.example.com"]   26s
virtualservice.networking.istio.io/v1-httpbin-vs       ["v1-httpbin-gw"]       ["same.example.com"]   16h
```


# View Service Mesh Route generated
```shell
$ oc -n ${CTRL_PLANE_NS} get route -l maistra.io/gateway-namespace=${NS}
NAME                                              HOST/PORT          PATH   SERVICES               PORT    TERMINATION   WILDCARD
httpbin-shard-v1-v1-httpbin-gw-1728dc3f992789a4   same.example.com          istio-ingressgateway   http2                 None

$ oc -n ${CTRL_PLANE_DMZ_NS} get route -l maistra.io/gateway-namespace=${NS}
NAME                                                  HOST/PORT                         PATH   SERVICES                         PORT    TERMINATION   WILDCARD
httpbin-shard-v1-v1-httpbin-dmz-gw-1728dc3f992789a4   same.example.com ... 1 rejected          istio-shard-dmz-ingressgateway   http2                 None

# detailed for shard
$ oc -n ${CTRL_PLANE_DMZ_NS} describe route -l maistra.io/gateway-namespace=${NS}
Name:			httpbin-shard-v1-v1-httpbin-dmz-gw-1728dc3f992789a4
Namespace:		istio-system-dmz
Created:		5 minutes ago
Labels:			maistra.io/gateway-name=v1-httpbin-dmz-gw
			maistra.io/gateway-namespace=httpbin-shard-v1
			maistra.io/gateway-resourceVersion=131241341
			maistra.io/generated-by=ior
Annotations:		maistra.io/original-host=same.example.com
Requested Host:		same.example.com
			   exposed on router router-shard (host router-router-shard.apps-shard.wkshop.rhbr-lab.com) 5 minutes ago
			rejected by router default:  (host router-default.apps.wkshop.rhbr-lab.com)HostAlreadyClaimed (5 minutes ago)
			  a route in another namespace holds same.example.com and is older than httpbin-shard-v1-v1-httpbin-dmz-gw-1728dc3f992789a4
Path:			<none>
TLS Termination:	<none>
Insecure Policy:	<none>
Endpoint Port:		http2

Service:	istio-shard-dmz-ingressgateway
Weight:		100 (100%)
Endpoints:	10.131.2.234:8080, 10.131.2.235:8080
```


# Test it
```shell
# check the internal route
$ curl -vH "Host: $MY_HOST" --resolve "$MY_HOST:80:$INGRESS_HOST" "http://$MY_HOST/status/418"
* Added same.example.com:80:10.36.5.2 to DNS cache
* Hostname same.example.com was found in DNS cache
*   Trying 10.36.5.2:80...
* Connected to same.example.com (10.36.5.2) port 80 (#0)
> GET /status/418 HTTP/1.1
> Host: same.example.com
> User-Agent: curl/7.79.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 418 Unknown
< server: istio-envoy
< date: Wed, 04 May 2022 12:36:44 GMT
< x-more-info: http://tools.ietf.org/html/rfc2324
< access-control-allow-origin: *
< access-control-allow-credentials: true
< content-length: 135
< x-envoy-upstream-service-time: 9
< set-cookie: fb79b86b9b224fa11cf259bd76f174e5=4534d569f18b3c195992113c4c28d573; path=/; HttpOnly
<

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`
* Connection #0 to host same.example.com left intact

# check the dmz route
$ curl -vH "Host: $MY_HOST" --resolve "$MY_HOST:80:$INGRESS_HOST_DMZ" "http://$MY_HOST/status/418"
* Added same.example.com:80:10.36.5.100 to DNS cache
* Hostname same.example.com was found in DNS cache
*   Trying 10.36.5.100:80...
* Connected to same.example.com (10.36.5.100) port 80 (#0)
> GET /status/418 HTTP/1.1
> Host: same.example.com
> User-Agent: curl/7.79.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 418 Unknown
< server: istio-envoy
< date: Wed, 04 May 2022 12:36:07 GMT
< x-more-info: http://tools.ietf.org/html/rfc2324
< access-control-allow-origin: *
< access-control-allow-credentials: true
< content-length: 135
< x-envoy-upstream-service-time: 13
< set-cookie: 900e2ad13639f4c7537c03c0513428c9=d35fe9e9ccdedffa0927b84daa379a2a; path=/; HttpOnly
<

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`
* Connection #0 to host same.example.com left intact

```