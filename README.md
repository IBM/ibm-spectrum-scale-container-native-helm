# ibm-spectrum-scale-container-native-helm
HELM charts to assist with IBM Spectrum Scale® container native and CSI driver installations on Red Hat® OpenShift®


## Abstract

This repository provides two sample Helm charts for deploying

- [*IBM Spectrum Scale Container Native Storage Access* (CNSA) v5.1.1.1](https://www.ibm.com/docs/en/scalecontainernative?topic=spectrum-scale-container-native-storage-access-5111) and 
- [*IBM Spectrum Scale CSI driver* v2.2.0](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=spectrum-scale-container-storage-interface-driver-220) 

in *two* steps with a *single* configuration file ([*config.yaml*](config.yaml)).

The Helm charts are based on the original YAML manifests from the public IBM Github repositories:

- [IBM Spectrum Scale container native](https://github.com/IBM/ibm-spectrum-scale-container-native)
- [IBM Spectrum Scale CSI](https://github.com/IBM/ibm-spectrum-scale-csi)

**Note**: These Helm charts are *not supported* by the IBM Spectrum Scale container native nor CSI offerings and are outside the scope of the IBM PMR process.
For the official documentation of the deployment of *IBM Spectrum Scale Container Native Storage Access*, 
please refer to the official [IBM Documentation](https://www.ibm.com/docs/en/scalecontainernative).

These Helm charts are only intended to provide ease of use for an *initial* deployment (`helm install`) of 
IBM Spectrum Scale® Container Native Storage Access (CNSA) and IBM Spectrum Scale® CSI driver on Red Hat® OpenShift®
for *Proof of Concepts (PoCs)*, *demos* or any other form of *evaluations* where no further lifecycle management and upgrade paths are considered. 
They are explicitely not intended and not suported for any production use! 

However, you can also use these Helm charts with `helm template` to generate the final YAML manifests from a *single* configuration file ([*config.yaml*](config.yaml))
and compare the output to the original YAML manifests that you would have edited and applied manually when following the official deployment steps in the 
[IBM Documentation](https://www.ibm.com/docs/en/scalecontainernative).
Once you confirm that these templated manifests meet your configuration (like with the original YAML manifests) then you can apply these 
conveniently with `helm template [...] | oc apply -f` without any further dependencies on Helm 
(i.e. they would be deployed as simple YAML manifests like in the original deployment instructions and not as an active Helm chart).
Refer to the section *Deploy IBM Spectrum Scale CNSA and CSI driver using Helm chart templating* in
[*INSTALL.md*](INSTALL.md#deploy-ibm-spectrum-scale-cnsa-and-csi-driver-using-helm-chart-templating) 
for more details about this deployment method.

Note, that these Helm charts do _not support_ any lifecycle management of IBM Spectrum Scale Container Native Storage Access and IBM Spectrum Scale CSI driver, 
especially, the `helm upgrade|rollback|uninstall` features are _not supported_ and are not expected to work. You need to follow the offcial IBM documentation to perform
any changes or upgrades to the deployment.

Future releases of IBM Spectrum Scale Container Native Storage Access (CNSA) and IBM Spectrum Scale CSI driver may come with different packaging and deployment options 
and no longer be suitable for a Helm chart deployment at which point this Helm chart will be discontinued.

This repository also provides a directory [(examples)](examples/) with some sample YAML manifests 

- [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml) (storage class)
- [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml) (persistent volume claim) 
- [*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml) (test pod using either *alpine* or Red Hat *ubi8/ubi-minimal* image)

to run a quick sanity check with a full dynamic storage provisioning cycle after the successful deployment of IBM Spectrum Scale CNSA/CSI.


## Installation

*Helm charts* allow to separate the *configurable parameters* from the *YAML manifests* of the individual components
and help to simplify and automate the deployment of containerized applications. 

An administrator only has to configure *one* central configuration file, here [*config.yaml*](config.yaml),
for the combined deployment of *IBM Spectrum Scale CNSA* and *IBM Spectrum Scale CSI driver*.

Once all prerequisites are met the deployment only requires the following steps:
 - Create the necessary namespaces, secrets and IBM Spectrum Scale CNSA/CSI user accounts  
 - Edit the [*config.yaml*](config.yaml) file to reflect your local environment
 - Deploy the IBM Spectrum Scale CNSA Helm Chart (*ibm-spectrum-scale*)
  -Deploy IBM Spectrum Scale CSI driver Helm Chart (*ibm-spectrum-scale-csi*)

The overall configuration is greatly simplified by minimizing and unifying the set of common parameters needed for the 
combined deployment of IBM Spectrum Scale CNSA and IBM Spectrum Scale CNSA CSI driver. It also allows to easily redirect 
all image references to a private image registry without editing any individual YAML manifests manually. 

The step by step instructions for the deployment are described in detail in [*INSTALL.md*](INSTALL.md).


## Disclaimer

These Helm charts are provided on an "AS IS" BASIS, 
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied, including, without limitation, any warranties or conditions
of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
PARTICULAR PURPOSE. You are solely responsible for determining the
appropriateness of using or redistributing the Work and assume any
risks associated with Your exercise of permissions under this License.


## Repository tags and releases

The *main* branch in this Github repository will carry tags to refer to different releases of these Helm charts for the 
combined deployment of specific *IBM Spectrum Scale CNSA* and *IBM Spectrum Scale CSI driver* releases.
E.g. a tag *v5.1.0.3-v2.1.0* (CNSA version-CSI driver version) refers to the Helm chart release for the combined deployment of
IBM Spectrum Scale CNSA *v5.1.0.3* and IBM Spectrum Scale CSI driver *v2.1.0*.

- Tag v5.1.0.3-v2.1.0: Helm charts for IBM Spectrum Scale CNSA v5.1.0.3 and IBM Spectrum Scale CSI driver v2.1.0
- Tag v5.1.0.3-v2.2.0: Helm charts for IBM Spectrum Scale CNSA v5.1.0.3 and IBM Spectrum Scale CSI driver v2.2.0
- Tag v5.1.1.1-v2.2.0: Helm charts for IBM Spectrum Scale CNSA v5.1.1.1 and IBM Spectrum Scale CSI driver v2.2.0

## Support

HELM charts for IBM Spectrum Scale container native and CSI are meant to assist with installation but are not a formally supported offering. 
These are not supported by the IBM Spectrum Scale container native nor CSI offerings and are outside the scope of the IBM PMR process. 

For supported methods of installation, please refer to the IBM Documentation for each product:

[IBM Spectrum Scale CSI documentation](https://www.ibm.com/docs/en/spectrum-scale-csi)

[IBM Spectrum Scale container native documentation](https://www.ibm.com/docs/en/scalecontainernative)


## Report Bugs 

For non-urgent issues, suggestions, recommendations, feel free to open an issue in [github](https://github.com/IBM/ibm-spectrum-scale-container-native-helm/issues).
Issues will be addressed as team availability permits.


## Contributing

We welcome contributions to this project, see [Contributing](CONTRIBUTING.md) for more details.

##### Note: This repository includes contributions from:

[Spectrum Scale CSI](https://github.com/IBM/ibm-spectrum-scale-csi)

[Spectrum Scale container native](https://github.com/IBM/ibm-spectrum-scale-container-native)


## Licensing

Copyright 2021 IBM Corp.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
