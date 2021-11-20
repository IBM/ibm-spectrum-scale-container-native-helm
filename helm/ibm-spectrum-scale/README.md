# IBM Spectrum Scale Container Native - Helm Chart

## ABSTRACT

This Helm chart deploys
- IBM Spectrum Scale Container Native Storage Access v5.1.1.4
- IBM Spectrum Scale CSI Driver v2.3.1

This Helm chart is only intended to provide ease of use for an 
initial deployment for Proof of Concepts (PoCs), demos or any other
types of evaluation where no further lifecycle managment and upgrade 
paths are considered. It is explicitly not intended for production use.

This Helm chart is not supported by the IBM Spectrum Scale container 
native nor IBM Spectrum Scale CSI offerings and are outside 
the scope of the IBM PMR process.

This Helm chart does not support any lifecycle management 
of IBM Spectrum Scale Container Native Storage Access and 
IBM Spectrum Scale CSI driver, especially, the 
`helm upgrade|rollback|uninstall` features are not supported 
and are not expected to work.

## REFERENCE

The Helm chart is hosted on Github at 
[IBM/ibm-spectrum-scale-container-native-helm](https://github.com/IBM/ibm-spectrum-scale-container-native-helm).

See [Helm Chart Deployment of IBM Spectrum Scale CNSA/CSI](https://github.com/IBM/ibm-spectrum-scale-container-native-helm/blob/main/INSTALL.md#helm-chart-deployment-of-ibm-spectrum-scale-cnsacsi)
for more details on the deployment.

The offical documentation for IBM Spectrum Scale Container Native and IBM Spectrum Scale CSI Driver
can be found at:
- [IBM Spectrum Scale Container Native](https://www.ibm.com/docs/en/scalecontainernative)
- [IBM Spectrum Scale CSi Driver](https://www.ibm.com/docs/en/spectrum-scale-csi)

## PREPARATIONS

The deployment of IBM Spectrum Scale Container Native requires 
certain mandatory planning and preparation steps.

Please see: 
- [IBM Spectrum Scale Container Native - Planning](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-planning),
- [IBM Spectrum Scale Container Native - Installation prerequisites](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installation-prerequisites) and
- [Installing the IBM Spectrum Scale container native operator and cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installing-spectrum-scale-container-native-operator-cluster).

## NAMESPACES

The deployment will create and use the following namespaces as listed below.
- ibm-spectrum-scale (CNSA namespace)
- ibm-spectrum-scale-operator (CNSA operator namespace)
- ibm-spectrum-scale-csi (CSI namespace)

These namespaces are not configurable in the Helm chart because additional 
objects are created and managed by the operators which have dependencies 
on these namespaces and are beyond the control of this Helm chart.

The namespaces will not be removed by Helm with `helm uninstall`.
The namespace manifests are located in the crds/ directory of the Helm chart
to ensure that they are applied automatically prior to the deployment 
of the manifests in the templates/ directory.

## VALUES

Copy the `values.yaml` file to your local working directory as `config.yaml` file and edit it accordingly
to reflect your local environment. The values in this file serve as input to configure the
IBM Spectrum Scale Container Native deployment.

Please handle the file with care as it holds sensitive information once configured with your CNSA/CSI GUI user credentials!

At minimum you need to specify the following parameters: 

(1) Accept the IBM Spectrum Scale license and select the proper IBM Spectrum Scale license (*data-access* or *data-management*):
``` 
license:
    accept: true
    license: data-access
```
(2) Specify the *credentials* for the created CNSA and CSI user accounts on the remote storage cluster GUI:
```
cnsaGuiUser:
  username: "cnsa_admin"
  password: "cnsa_PASSWORD"

csiGuiUser:
  username: "csi_admin"
  password: "csi_PASSWORD"
```
(3) Specify the *name* of the *local* and *remote* IBM Spectrum Scale file system:
```
primaryFilesystem:
  localFs:          "fs1"      <- local CNSA file system name (can be chosen freely), will be mounted at /mnt/<localFs>
  remoteFs:         "ess_fs1"  <- remote file system name on storage cluster (must exist)
```
(4) Specify the *GUI node* for accessing the remote storage cluster:
```
remoteCluster:
  gui:
    host:               "remote-scale-gui.mydomain.com"
```

This configuration will automatically create the *secrets* for the CNSA/CSI GUI users 
(`cnsa-remote-gui-secret`, `csi-remote-gui-secret`) 
in their respective namespaces (CNSA: `ibm-spectrum-scale`, CSI: `ibm-spectrum-scale-csi`), 
create a *RemoteCluster CR* with name `primary-storage-cluster` and deploy IBM Spectrum Scale CNSA with the CSI driver on 
all OpenShift worker nodes with the default *nodeSelector* `node-role.kubernetes.io/worker: ""`. 

Further settings can be configured as needed to customize the deployment. These settings are listed and
and described in the `config.yaml`/`values.yaml` file with references to the official documentation. 

## DEPLOYMENT

(1) Create the release namespace "ibm-spectrum-scale" for the Helm chart:
```
# oc apply -f helm/ibm-spectrum-scale/crds/Namespace-ibm-spectrum-scale.yaml
```

(2) Edit the `config.yaml` (local copy of `values.yaml`) to configure the Helm chart deployment for your environment:
```
# vi config.yaml
```

(3) Deploy the Helm chart:
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
```
with
  - ibm-spectrum-scale :         *Release name* of the deployed Helm chart; can be chosen freely
  - helm/ibm-spectrum-scale :    Helm chart for IBM Spectrum Scale CNSA
  - -f config.yaml :             The customized configuration file as input for the Helm chart deployment
  - -n ibm-spectrum-scale :      The *release namespace* to use for the Helm chart (here we select the CNSA namespace)

## HOOKS

The Helm chart makes use of *hooks* (Kubernetes *Jobs*) to test that the provided user credentials for CNSA and CSI on the 
storage cluster GUI are properly configured before deploying the application. 
The *hooks* run with the credentials being provided in the *config.yaml* file (`createSecrets: true`) 
or with the manually created *secrets* (`createSecrets: false`).

If you wish to deploy the Helm chart *without* hooks just add the `--no-hooks` option:
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml --no-hooks -n ibm-spectrum-scale
```

If the hooks indicate a failure the deployment of the Helm chart will fail before
any further templates are deployed. Only the CRDs and namespaces (located in the `crds/` directory) will have been applied.

Check the logs to identify why the CNSA / CSI user access to the storage GUI failed:
```
# oc logs job/ibm-spectrum-scale-cnsa-gui-access-test -n ibm-spectrum-scale
# oc logs job/ibm-spectrum-scale-csi-gui-access-test -n ibm-spectrum-scale-csi
```
A `401 Unauthorized Error` indicates that the provided credentials are not correct or that
the user has not been properly created on the storage cluster GUI.

## REMOVAL

IMPORTANT: Don't simply run `helm uninstall` as some resources which were created by the operators
require a proper clean-up first!

To remove *IBM Spectrum Scale Container Native Storage Access* with *IBM Spectrum Scale CSI driver* 
please refer to the official IBM documentation at 
[Cleaning up the container native cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-cleaning-up-container-native-cluster)

The complete removal of the IBM Spectrum Scale CNSA & CSI requires some distinctive steps.

Make sure that all *applications* stop using persistent storage provided by IBM Spectrum Scale 
and verify that all related SC, PVC and PV objects for these applications are removed.

The complete removal of the IBM Spectrum Scale CNSA and CSI involves these steps: 

(1) Delete the *ibm-spectrum-scale-controller-manager* deployment:
```
# oc delete deployment ibm-spectrum-scale-controller-manager -n ibm-spectrum-scale-operator
```

(2) Delete the *csiscaleoperators* CR to remove IBM Spectrum Scale CSI:
```
# oc delete  csiscaleoperators ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi
```
Wait until all resources from the previous steps were successfully deleted.

(3) Uninstall the Helm chart to remove IBM Spectrum Scale CNSA:
```
# helm uninstall ibm-spectrum-scale -n ibm-spectrum-scale
```

(4) Delete the applied IBM Spectrum Scale CRDs and namespaces:
```
# oc delete -f helm/ibm-spectrum-scale/crds
```

(5) Clean up remaining IBM Spectrum Scale CNSA PVs and Storage Classes:
```
# oc delete pv -lapp.kubernetes.io/instance=ibm-spectrum-scale,app.kubernetes.io/name=pmcollector
# oc delete sc -lapp.kubernetes.io/instance=ibm-spectrum-scale,app.kubernetes.io/name=pmcollector
```

(6) Clean up local IBM Spectrum Scale directories on the OpenShift worker nodes:
```
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## $a ##"; oc debug node/$a -- chroot /host sh -c "rm -rf /var/mmfs; rm -rf /var/adm/ras"; sleep 5; done
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## $a ##"; oc debug node/$a -- chroot /host sh -c "ls /var/mmfs; ls /var/adm/ras"; sleep 5; done
```
Make sure that all these directories have been removed successfully.

(7) Remove all IBM Spectrum Scale CNSA node labels:
```
# oc label node --all scale.spectrum.ibm.com/role- scale.spectrum.ibm.com/designation- scale-
```

(8) Clean up remote storage cluster:

(a) Remove the authorization for the remote mount for IBM Spectrum Scale CNSA:
```
# mmauth show all
# mmauth delete ibm-spectrum-scale.[your-OpenShift-domain]
```

(b) Remove the primary fileset created by IBM Spectrum Scale CSI:
```
# mmlsfileset [your-file-system-name] -L
# mmunlinkfileset [your-file-system-name] primary-fileset-[your-former-CNSA-file-system-name]-[your-former-CNSA-cluster-ID]
# mmdelfileset [your-file-system-name] primary-fileset-[your-former-CNSA-file-system-name]-[your-former-CNSA-cluster-ID] -f
```

## DISCLAIMER

  This Helm chart is only intended to provide ease of use for an 
  initial deployment for Proof of Concepts (PoCs), demos or any other 
  types of evaluation where no further lifecycle managment and upgrade 
  paths are considered. It is explicitly not intended for production use.
  
  This Helm chart is not supported by the IBM Spectrum Scale container 
  native nor IBM Spectrum Scale CSI offerings and are outside 
  the scope of the IBM PMR process.

  This Helm chart is provided on an "AS IS" BASIS, WITHOUT WARRANTIES 
  OR CONDITIONS OF ANY KIND, either express or implied, including, 
  without limitation, any warranties or conditions of TITLE, 
  NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. 
  You are solely responsible for determining the appropriateness of 
  using or redistributing the Work and assume any risks associated with
  Your exercise of permissions under this License.

  Note, that this Helm chart does not support any lifecycle management 
  of IBM Spectrum Scale Container Native Storage Access and 
  IBM Spectrum Scale CSI driver, especially, the 
  helm upgrade|rollback|uninstall features are not supported 
  and are not expected to work. 
  You need to follow the offcial IBM documentation to perform any 
  changes or upgrades to the deployment.
