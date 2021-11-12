#! /usr/bin/gawk -f

# --------------------------------------------------------------------
#  split.awk V1.0   Author: Gero Schmidt                   2021.10.28
# --------------------------------------------------------------------
#  Splits concatenated YAML files into individual files 
# --------------------------------------------------------------------

BEGIN { fname="file"; filecnt=1; j=0; file=sprintf("%s-%d",fname,filecnt); }

{
  if ($1=="---") 
  {
    filecnt++; 
    file=sprintf("%s-%d",fname,filecnt); 
    next;
  }
  print $0 > file; 
  j++;
}

END { printf("## DONE ## Processed %d lines and created %d files\n\n", j,filecnt); }
