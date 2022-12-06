#! /usr/bin/gawk -f
# --------------------------------------------------------------------
#  yaml-split.awk V1.0   Author: Gero Schmidt              2022-12-06
# --------------------------------------------------------------------
#  Splits concatenated YAML files into individual files 
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

BEGIN { fname="file"; filecnt=1; j=0; file=sprintf("%s-%d",fname,filecnt); }

{
  if (substr($0,1,3)=="---" || filecnt==1) 
  {
    filecnt++; 
    file=sprintf("%s-%d",fname,filecnt); 
    next;
  }
  print $0 > file; 
  j++;
}

END { printf("## DONE ## Processed %d lines and created %d files\n\n", j,filecnt); }
