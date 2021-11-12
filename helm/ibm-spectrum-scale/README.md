# IBM Spectrum Scale Container Native - Helm Chart

## ABSTRACT

This Helm chart deploys
- IBM Spectrum Scale Container Native Storage Access v5.1.1.4
- IBM Spectrum Scale CSI Driver v2.3.1

This Helm chart is only intended to provide ease of use for an 
initial deployment for Proof of Concepts (PoCs), demos or any other 
form of evaluations where no further lifecycle managment and upgrade 
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

The Helm chart is hosted in Github at 
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

Please see 
[IBM Spectrum Scale Container Native - Planning](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-planning),
[IBM Spectrum Scale Container Native - Installation prerequisites](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installation-prerequisites) and
[Installing the IBM Spectrum Scale container native operator and cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installing-spectrum-scale-container-native-operator-cluster)
for more information.

## NAMESPACES

The deployment will create and use the following namespaces as listed below.
- ibm-spectrum-scale (CNSA namespace)
- ibm-spectrum-scale-operator (CNSA Operator namespace)
- ibm-spectrum-scale-csi (CSI  namespace)

These namespaces are not configurable in the Helm chart because further 
K8s objects are created and managed by the operators which have dependencies 
on these namespaces and are beyond the control of this Helm chart.
The namespaces will not be removed by Helm with `helm uninstall`.
The namespace manifests are located in the crds/ directory of the Helm chart
to ensure that they are applied automatically prior to the deployment 
of the manifests in the templates/ directory

## VALUES

Copy the `values.yaml` file to your local working directory as `config.yaml` file and edit it accordingly
to reflect your local environment. The values in this file serve as input to configure the
IBM Spectrum Scale Container Native deployment. 
Handle the file with care as it holds sensitive information once configured with your CNSA/CSI GUI user credentials.

At minimum you need to specify the following parameters: 

(1) Accept the IBM Spectrum Scale license:
``` 
license:
    accept: true
    license: data-access
```
(2) Specify the *credentials* for the created CNSA and CSI user accounts on the storage cluster GUI:
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
  localFs:          "fs1"      <- local CNSA file system name (free to chose), to be mounted at /mnt/<localFs>
  remoteFs:         "ess_fs1"  <- remote file system name on storage cluster (must exist)
```
(4) Specify the *GUI node* for accessing the remote storage cluster:
```
remoteCluster:
  gui:
    host:               "remote-scale-gui.mydomain.com"
```

## DEPLOYMENT

(1) Create the release namespace "ibm-spectrum-scale" for the Helm chart (otherwise use the "default" namespace)
```
# oc apply -f helm/ibm-spectrum-scale/crds/Namespace-ibm-spectrum-scale.yaml
```

(2) Edit the `config.yaml` to configure the Helm chart deployment
```
# vi config.yaml
```

(3) Deploy the Helm chart
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
```
with
-  ibm-spectrum-scale :         Release name of the Helm deployment, can be chosen freely
-  helm/ibm-spectrum-scale :    Helm chart of IBM Spectrum Scale CNSA
-  -f config.yaml :             The customized configuration for the Helm chart deployment
-  -n ibm-spectrum-scale :      Release namespace to use for the Helm chart

## HOOKS

The Helm chart makes use of hooks to test if the user credentials for CNSA and CSI on the 
storage cluster GUI as specified in the CNSA and CSI secrets are properly configured before
deploying the application.

To deploy the Helm chart *without* hooks just add the `--no-hooks` option:
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml --no-hooks -n ibm-spectrum-scale
```
If the hooks indicate a failure the deployment of the Helm chart will fail before
any further templates are deployed. Only the CRDs and namespaces will have been applied.

Check the logs to identify why the CNSA / CSI access to the storage GUI failed:
```
# oc logs job/ibm-spectrum-scale-cnsa-gui-access-test -n ibm-spectrum-scale
# oc logs job/ibm-spectrum-scale-csi-gui-access-test -n ibm-spectrum-scale-csi
```
A `401 Unauthorized Error` indicates that the provided credentials are not correct or that
the user has not been properly created on the storage cluster GUI.

## REMOVAL

The complete removal of the IBM Spectrum Scale CNSA & CSI requires some distinctive steps.
Don't simply run a "helm uninstall" as the additional resources created by the operators
require a proper clean-up.

To remove *IBM Spectrum Scale Container Native Storage Access* and *IBM Spectrum Scale CSI driver* 
plugin please follow instructions in
[Cleaning up the container native cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-cleaning-up-container-native-cluster)

Make sure that all applications stop using persistent storage provided by IBM Spectrum Scale 
and verify that all related SC, PVC and PV objects are removed.

(1) Delete the operator
```
# oc delete operator
# oc delete csiscaleoperators ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi-driver


# oc delete crd csiscaleoperators.csi.ibm.com
# oc delete project ibm-spectrum-scale-csi-driver
```
with *ibm-spectrum-scale-csi* being the Helm chart release name and *-n ibm-spectrum-scale-csi-driver* referring to the CSI driver namespace.


To completely remove IBM Spectrum Scale CSI driver you also have to remove its primary fileset *spectrum-scale-csi-volume-store* (default name) from the remote file system
(here *ess3k_fs1*) on the remote storage cluster:
```
# mmlsfileset ess3k_fs1 -L
Filesets in file system 'ess3k_fs1':
Name                            Id      RootInode  ParentId Created                      InodeSpace      MaxInodes    AllocInodes Comment
root                             0              3        -- Mon May 11 20:19:22 2020        0             15490304         500736 root fileset
spectrum-scale-csi-volume-store  1         524291         0 Tue Jun  8 17:05:38 2021        1              1048576          52224 Fileset created by IBM Container Storage Interface driver

# mmunlinkfileset ess3k_fs1 spectrum-scale-csi-volume-store
Fileset spectrum-scale-csi-volume-store unlinked.

# mmdelfileset ess3k_fs1 spectrum-scale-csi-volume-store -f
Checking fileset ...
Checking fileset complete.
Deleting user files ...
 100.00 % complete on Wed Jun 30 14:59:19 2021  (     52224 inodes with total        204 MB data processed)
Deleting fileset ...
Fileset spectrum-scale-csi-volume-store deleted.
```
Finally, remove the *scale=true* label (and other labels that you may have configured additionally) from the worker nodes:
```
# oc label nodes -l scale=true scale-
```

(2) The Helm chart resources of the **IBM Spectrum Scale CNSA** deployment can be removed using
```
# oc delete scalecluster ibm-spectrum-scale -n ibm-spectrum-scale
# helm uninstall ibm-spectrum-scale -n ibm-spectrum-scale
# oc delete crd scaleclusters.scale.ibm.com
# oc delete scc ibm-spectrum-scale-privileged
# oc delete pvc -l app=scale-pmcollector -n ibm-spectrum-scale
# oc delete pv -l app=scale-pmcollector
# oc delete sc -l app=scale-pmcollector
```
with *ibm-spectrum-scale* being the Helm chart release name and *-n ibm-spectrum-scale* referring to the CNSA namespace.

Only delete the project and following resources if you have no intention to redeploy IBM Spectrum Scale CNSA:
```
# oc delete project ibm-spectrum-scale
# oc debug node/<openshift_spectrum-scale_worker_node> -T -- chroot /host sh -c "rm -rf /var/mmfs; rm -rf /var/adm/ras"
# oc get nodes -ojsonpath="{range .items[*]}{.metadata.name}{'\n'}" | xargs -I{} oc annotate node {} scale.ibm.com/nodedesc-
```
Also make sure to clean up the remote storage cluster. If you skip this step and reinstall IBM Spectrum Scale CNSA then the 
*remote mount* will fail if the stale `mmauth` entry of the previously deleted IBM Spectrum Scale CNSA cluster still exists:
```
# mmauth show all
Cluster name:        ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com
Cipher list:         AUTHONLY
SHA digest:          bd3e0c087ea440c63e610b4e294d43222856b230dff6cb8a47376f3fd6a5de89
File system access:  ess3k_fs1 (rw, root allowed)

Cluster name:        ess3000.bda.scale.ibm.com (this cluster)
Cipher list:         AUTHONLY
SHA digest:          8e29e5b130934a8938d00027bebaddca324dafe3b901fbe66275eaca4f620a6a
File system access:  (all rw)
```
Remove the IBM Spectrum Scale CNSA client cluster authorization by issuing:
```
# mmauth delete ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com
mmauth: Propagating the cluster configuration data to all affected nodes.
mmauth: Command successfully completed
```



## DISCLAIMER

  This Helm chart is only intended to provide ease of use for an 
  initial deployment for Proof of Concepts (PoCs), demos or any other 
  form of evaluations where no further lifecycle managment and upgrade 
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
