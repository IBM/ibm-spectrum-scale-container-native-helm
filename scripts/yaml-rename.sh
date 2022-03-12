#!/usr/bin/bash
# --------------------------------------------------------------------
#  yaml-rename.sh V1.0   Author: Gero Schmidt              2021-10-28
# --------------------------------------------------------------------
#  Renames all YAML files in current directory to "kind-name.yaml"
# --------------------------------------------------------------------
#  Usage:  wget https://.../ibm-spectrum-scale-operator.yaml
#          mkdir ibm-spectrum-scale-operator
#          cd ibm-spectrum-scale-operator
#          ../yaml-split.awk ../ibm-spectrum-scale-operator.yaml
#          ../yaml-rename.sh 
# --------------------------------------------------------------------
#  Usage:  wget https://.../scale_v1beta1_cluster_cr.yaml
#          mkdir scale_v1beta1_cluster_cr
#          cd scale_v1beta1_cluster_cr
#          ../yaml-split.awk ../scale_v1beta1_cluster_cr.yaml
#          ../yaml-rename.sh 
# --------------------------------------------------------------------

ls file* -1|while read a; do echo $a; mv $a $(grep '^kind:' $a| cut -d' ' -f2)-$(grep -m1 '^  name:' $a |cut -d' ' -f4).yaml ; done
