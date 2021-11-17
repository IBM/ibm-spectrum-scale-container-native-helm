ls file* -1|while read a; do echo $a; mv $a $(grep '^kind:' $a| cut -d' ' -f2)-$(grep -m1 '^  name:' $a |cut -d' ' -f4).yaml ; done
