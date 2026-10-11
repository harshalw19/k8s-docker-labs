https://sysdig.com/blog/kubernetes-admission-controllers/

https://www.baeldung.com/java-kubernetes-admission-controller

https://www.youtube.com/watch?v=1mNYSn2KMZk
	https://github.com/marcel-dempers/docker-development-youtube-series
	https://github.com/marcel-dempers/docker-development-youtube-series/blob/master/kubernetes/admissioncontrollers/introduction/tls/ssl_generate_self_signed.md





### Introduction to Kubernetes Admission Controllers

This tutorial covers **Kubernetes Admission Controllers**, the gatekeepers of the Kubernetes API. Based on the *"Cloud With VarJosh"* course, this guide explains how they function, the difference between mutating and validating controllers, and how to manage them.

---

## 1. Introduction to Admission Controllers
Admission Controllers are pieces of code that intercept requests to the Kubernetes API server **after** the request is authenticated and authorized, but **before** the object is persisted in **etcd**.

They serve two primary purposes:
* **Enforce Policies:** Ensuring resources adhere to organizational standards (e.g., "no public images allowed").
* **Modify Requests:** Automatically injecting sidecars or default labels into incoming resource manifests.

> **Note:** Admission controllers only apply to **write operations** (Create, Update, Patch, Delete). They do not trigger for read operations like `get` or `list`.

---

## 2. Types of Admission Controllers
Kubernetes categorizes these controllers based on their behavior:

### A. Mutating Admission Controllers
These controllers can **modify** the request object.
* **Example:** The `DefaultStorageClass` controller automatically adds a storage class name to a PersistentVolumeClaim (PVC) if the user left it blank.

### B. Validating Admission Controllers
These controllers can only **allow or deny** a request; they cannot modify it.
* **Example:** Imagine your company has a security policy that only allows container images from your private, scanned corporate registry (e.g., `mycorp.azurecr.io`).
    * **The Request:** A developer tries to run a pod using `image: nginx:latest`.
    * **The Action:** The Validating Admission Controller inspects the `image` field and sees it doesn't match the required registry.
    * **The Result:** The controller **denies** the request. The developer receives an error: *"Internal Policy: Images from public Docker Hub are prohibited."*

### C. Dual-Function Controllers
Some plugins do both.
* **Example:** `LimitRanger` acts as **mutating** by injecting default CPU/Memory requests if missing, and as **validating** by rejecting requests that exceed maximum allowed limits.

---

## 3. Built-in vs. Custom Controllers
* **Built-in:** Compiled into the `kube-apiserver` binary (e.g., `NodeRestriction`, `ResourceQuota`).
* **Custom (Webhooks):** External services that the API server calls via HTTP. Popular tools like **OPA (Open Policy Agent) Gatekeeper** and **Kyverno** are implemented this way.

---

## 4. The Admission Control Sequence
When a request hits the API server, it follows a strict order:



1.  **Authentication & Authorization:** Verifies who you are and if you have permission.
2.  **Mutating Phase:** All mutating controllers run. If a request is modified, the change is kept in memory.
3.  **Object Validation:** Built-in schema validation occurs.
4.  **Validating Phase:** All validating controllers run. If **any** controller denies the request, the entire operation fails immediately.
5.  **Persistence:** If everything passes, the object is saved to **etcd**.

---

## 5. Hands-on: Enabling and Disabling Plugins
In a `kubeadm` deployment, admission controllers are configured via flags in the `kube-apiserver` static pod manifest.

### How to Check/Modify:
1.  Access your control plane node.
2.  Open the manifest file: `/etc/kubernetes/manifests/kube-apiserver.yaml`.
3.  **To Enable:** Add the plugin to the `--enable-admission-plugins` flag.
4.  **To Disable:** Use the `--disable-admission-plugins` flag.

### Demo Example: Disabling ServiceAccount
If you disable the `ServiceAccount` plugin, Kubernetes will stop automatically mounting the default service account token into your pods.
* **Before disabling:** `kubectl describe pod` shows a mount for the service account token.
* **After disabling:** New pods will have **no** service account information or token mounts.

---

## 6. Key Built-in Plugins to Know
* **NodeRestriction:** Limits a kubelet's ability to modify only its own Node and Pod objects—a critical security feature.
* **AlwaysPullImages:** Modifies every pod's image pull policy to `Always`. This ensures users cannot "steal" images already cached on a node without credentials.
* **ResourceQuota:** Ensures that a namespace does not exceed its allocated hardware resources.

---

## 7. Summary of the Flow

| Phase | Action | Result |
| :--- | :--- | :--- |
| **Mutating** | Modify/Defaulting | Changes the YAML in memory |
| **Validating** | Approval/Rejection | Allows or Blocks the request |
| **etcd** | Storage | Resource is created in the cluster |

---




### Hands-On: Admission Controllers in Action

## 1. Checking Enabled Plugins
To see which plugins are currently active on your API server:
```bash
kubectl get po <api-server-pod-name> -n kube-system -o yaml | grep admission
NodeRestriction: A security plugin that prevents nodes (kubelets) from modifying objects they don't own.2. NamespaceAutoProvision DemoBy default, creating a pod in a non-existent namespace fails:Bashkubectl run newpod --image=nginx -n no-ns
# Error: namespaces "no-ns" not found
To enable auto-provisioning:Edit /etc/kubernetes/manifests/kube-apiserver.yaml.Add NamespaceAutoProvision to the --enable-admission-plugins list.Save and wait for the API server to restart. Now, the namespace will be created automatically upon pod creation.3. Enforcing Resource Quotas (Validating)Create a namespace and a quota to limit resources.Bashkubectl create namespace quota-test
quota.yamlYAMLapiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: quota-test
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: 500Mi
    limits.cpu: "1"
    limits.memory: 1Gi
oversized-pod.yaml (This will be rejected)YAMLapiVersion: v1
kind: Pod
metadata:
  name: large-pod
  namespace: quota-test
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "800Mi" # Exceeds 500Mi quota
        cpu: "200m"
4. LimitRange Demo (Mutating & Validating)A LimitRange provides default values and constraints.limitrange.yamlYAMLapiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: default
spec:
  limits:
  - type: Container
    default:
      cpu: "0.5"        # Default Limit
      memory: "1Gi"     # Default Limit
    defaultRequest:
      cpu: "0.25"       # Default Request
      memory: "0.5Gi"   # Default Request
    max:
      cpu: "1"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "250Mi"
5. Recommended Default PluginsPluginCategoryPurposeNodeRestrictionSecurityLimits kubelet permissions.NamespaceLifecycleStabilityPrevents actions in terminating namespaces.ServiceAccountAutomationAutomates token management.LimitRangerResourcesEnforces default constraints.ResourceQuotaResourcesPrevents "noisy neighbor" issues.FULL TUTORIAL: Mutating Admission WebhookAdmission Controllers are API request interceptors. 

---

###custom Mutating admission controller

This tutorial implements a custom Mutating Webhook that injects a logging sidecar into any pod labeled with inject-logger: "true".File StructurePlaintextlogger-webhook/
 ├── server.py
 ├── csr.conf
 ├── deployment.yaml
 ├── service.yaml
 ├── mutating-webhook.yaml
 └── pod.yaml
STEP 1: The Webhook Server (server.py)This Flask app receives an AdmissionReview and returns a JSON Patch.Pythonfrom flask import Flask, request, jsonify
import base64
import json

app = Flask(__name__)

@app.route('/mutate', methods=['POST'])
def mutate():
    req = request.get_json()
    uid = req.get("request", {}).get("uid")
    pod = req["request"]["object"]
    labels = pod.get("metadata", {}).get("labels", {})

    admission_response = {"uid": uid, "allowed": True}

    if labels.get("inject-logger") == "true":
        patch = [
            {
                "op": "add",
                "path": "/spec/containers/-",
                "value": {
                    "name": "log-agent",
                    "image": "busybox",
                    "command": ["sh", "-c", "while true; do echo 'logging...'; sleep 5; done"]
                }
            }
        ]
        admission_response.update({
            "patchType": "JSONPatch",
            "patch": base64.b64encode(json.dumps(patch).encode()).decode()
        })

    return jsonify({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": admission_response
    })

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=443, ssl_context=("/tls/tls.crt", "/tls/tls.key"))
STEP 2 & 3: Generate SAN CertificatesCreate the private key and use the Kubernetes CA to sign it to ensure the API server trusts your webhook.csr.confIni, TOML[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = logger-webhook-svc.kube-system.svc

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = logger-webhook-svc
DNS.2 = logger-webhook-svc.kube-system
DNS.3 = logger-webhook-svc.kube-system.svc
Generate and Sign:Bashopenssl genrsa -out tls.key 2048
openssl req -new -key tls.key -out tls.csr -config csr.conf
openssl x509 -req -in tls.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out tls.crt -days 365 -extensions req_ext -extfile csr.conf
STEP 4: Create Secret & ConfigMapBashkubectl create secret tls logger-webhook-tls \
  -n kube-system \
  --cert=tls.crt \
  --key=tls.key

kubectl create configmap webhook-code --from-file=server.py -n kube-system
STEP 5 & 6: Deployment & Servicedeployment.yamlYAMLapiVersion: apps/v1
kind: Deployment
metadata:
  name: logger-webhook
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logger-webhook
  template:
    metadata:
      labels:
        app: logger-webhook
    spec:
      containers:
        - name: webhook
          image: tiangolo/uwsgi-nginx-flask:python3.10
          command: ["python3", "/app/server.py"]
          volumeMounts:
            - name: tls
              mountPath: "/tls"
            - name: code
              mountPath: "/app"
      volumes:
        - name: tls
          secret:
            secretName: logger-webhook-tls
        - name: code
          configMap:
            name: webhook-code
service.yamlYAMLapiVersion: v1
kind: Service
metadata:
  name: logger-webhook-svc
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 443
  selector:
    app: logger-webhook
STEP 7 & 8: MutatingWebhookConfigurationExtract your cluster CA to tell Kubernetes to trust the webhook.BashCA_BUNDLE=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# In mutating-webhook.yaml, ensure ${CA_BUNDLE} is replaced
sed "s/\${CA_BUNDLE}/${CA_BUNDLE}/g" mutating-webhook.yaml | kubectl apply -f -
STEP 10 & 11: VerifyLabel the namespace: kubectl label ns default logging=enabledCreate pod: kubectl apply -f pod.yamlCheck containers: kubectl get pod app1 -o jsonpath='{.spec.containers[*].name}'Result: app log-agent
**Would you like me to help you create a Validating Webhook next to block pods that do
