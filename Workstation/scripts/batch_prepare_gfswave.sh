#!/bin/bash -l

# checkpoint function  usage:  checkpoint $? Name
function checkpoint {
  if (( $1 == 0 )); then
    echo "$2 OK"
  else
    echo "$2 FAILED, RC=$1"
  fi
}

conda activate work

#                                           
# prepare the files for push to polar       
#                                           

srcdir='/scratch1/NCEPDEV/stmp2/Samira.Ardani/github/EMC-JCOMM/EMC_waves-prod-gen/JCOMM/scripts'
fixdir='/scratch1/NCEPDEV/stmp2/Samira.Ardani/github/EMC-JCOMM/EMC_waves-prod-gen/JCOMM/fix'
workdir='/scratch1/NCEPDEV/stmp2/Samira.Ardani/github/EMC-JCOMM/JCOMM-test'

#USERpolar='waves@emcrzdm.ncep.noaa.gov'
USERpolar='waves@vm-cprk-emcrzdm02.ncep.noaa.gov'  ## 01, 02, 03
polardir='/home/ftp/polar/waves/JCOMM'

SSH=/usr/bin/ssh
SCP=/usr/bin/scp

#export PATH=/export/emc-lw-dspindle/dspindler/anaconda3/envs/work/bin:$PATH

TODAY=$(date +'%Y%m%d')
theDate=${1:-$TODAY}   ## use a passed-in date if given, else use TODAY
cycles=${2:-'00 06 12 18'}
#theDate='20230207'
#cycles='06'
echo "running JCOMM2 for GFS-Wave for $theDate"

#mkdir -p ${workdir}/${theDate}   ## done from devwcoss
cp ${srcdir}/fix_ranges.py ${workdir}/${theDate}/fix_ranges.py
cp ${fixdir}/jcomm.rule.filter ${workdir}/${theDate}/rule.filter
cp ${fixdir}/jcomm.paramIDs.txt ${workdir}/${theDate}/paramIDs.txt

cd ${workdir}/${theDate}
#rm -f ${workdir}/${theDate}/out*.grib2
#rm -f ${workdir}/${theDate}/wave*.grib2*

touch jcomm_checks.log
rm -f ${workdir}/${theDate}/jcomm_checks.log
touch jcomm_checks.log

touch all_range.txt

prep_file='yes'
qc_file='yes'
push_ftp='yes'

for cyc in ${cycles}
do
  echo "running prepare_gfswave.sh for $theDate ${cyc}" >> jcomm_checks.log
  if [[ "${prep_file}" = 'yes' ]]
  then
    # check if the file has been pushed from devwcoss
    if [[ -a ${workdir}/${theDate}/cat${cyc}.grib2 ]]; then
    
      # change the shortName for each variable:
      echo "grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2"
      grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2
      checkpoint $? GRIB_FILTER >> jcomm_checks.log
      
      # fix the primary wave period range and create data_range.txt
      echo "***     ***" >> all_range.txt
      echo "python fix_ranges.py out${cyc}.grib2"
      python fix_ranges.py out${cyc}.grib2
      cat data_range.txt >> all_range.txt
      echo "***     ***" >> all_range.txt
      checkpoint $? FIX_RANGES >> jcomm_checks.log
      
      # change the compression to simple (from jpeg2000)
      echo "grib_set -r -s packingType=grid_simple out${cyc}.grib2 wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
      grib_set -r -s packingType=grid_simple out${cyc}.grib2.fix wave_NCEP_${theDate}${cyc}_prod_fc.grib2
      checkpoint $? GRIB_SET >> jcomm_checks.log
      
      # create MD5 check sum for wave_NCEP_${theDate}${cyc}_prod_fc.grib
      echo "creating MD5 check sum for wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
      /usr/bin/md5sum wave_NCEP_${theDate}${cyc}_prod_fc.grib2 > wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5
      checkpoint $? WCOSS_MD5 >> jcomm_checks.log
    
    else
      echo "files not pushed from devwcoss" >> jcomm_checks.log
      echo "exiting now" >> jcomm_checks.log
      exit
    fi
    
  fi # prep_file
  
  if [[ "${qc_file}" = 'yes' ]]
  then
    # check number of messages
    num_messages=`grib_count wave_NCEP_${theDate}${cyc}_prod_fc.grib2`
    OK=$?
    checkpoint $OK NUM_MESS >> jcomm_checks.log
    if [ "${num_messages}" != 1045 ]
    then
      push_ftp='no'
      echo ' '
      echo ' ************************************************* '
      echo ' *** Incorrect number of messages in grib file *** '
      echo " ***   Number of messages = ${num_messages}    *** "
      echo " ***   push_ftp set to $push_ftp               *** "
      echo ' ************************************************* '
    fi # number of messages
    
    # check list of variables
    grib_ls -pparamId -wstep=0 wave_NCEP_${theDate}${cyc}_prod_fc.grib2 | head -n -3 | tail -n +3 | awk '{print $1}' > paramIDs${theDate}${cyc}.txt
    #sed -i -e '1,2d;$d' paramIDs${theDate}${cyc}.txt  # remove the first 2 and last line
    #sed -i -e '$d' paramIDs${theDate}${cyc}.txt       # remove blank line
    #sed -i -e '$d' paramIDs${theDate}${cyc}.txt       # keep only paramIDs
    
    diff paramIDs.txt paramIDs${theDate}${cyc}.txt
    OK=$?
    checkpoint $OK DIFF_PARAMS >> jcomm_checks.log
    if [[ "$OK" != '0' ]]
    then
      push_ftp='no'
      echo ' '
      echo ' ************************************* '
      echo ' ***      Different paramIDs       *** '
      echo " ***   push_ftp set to $push_ftp   *** "
      echo ' ************************************* '
    fi # variables list
    
    # variables in expected range?  
    
  fi # qc_file
  
  echo ' '
  echo ' ********************************* '
  echo ' ***     Out of qc_file        *** '
  echo " *** push_ftp set to $push_ftp *** "
  echo ' ********************************* '
  
  cd ${workdir}/${theDate}
  if [[ "${push_ftp}" = 'yes' ]]
  then
    # blind copy (add "." to start of filename) it to the ftp site for JCOMM2:
    echo "copying wave_NCEP_${theDate}${cyc}_prod_fc.grib2 to Polar"
    $SCP -o ConnectTimeout=300 wave_NCEP_${theDate}${cyc}_prod_fc.grib2 ${USERpolar}:${polardir}/.wave_NCEP_${theDate}${cyc}_prod_fc.grib2 1>jcomm_copy_${cyc}.log 2>&1
    OK=$?
    checkpoint $OK SCP_WCOSS >> jcomm_checks.log
    if [[ "$OK" != '0' ]]
    then
      echo "trying to copy again"
      $SCP -o ConnectTimeout=300 wave_NCEP_${theDate}${cyc}_prod_fc.grib2 ${USERpolar}:${polardir}/.wave_NCEP_${theDate}${cyc}_prod_fc.grib2 1>jcomm$
      OK=$?
      checkpoint $OK 2nd_SCP >> jcomm_checks.log
      if [[ "$OK" != '0' ]]
        then
        push_ftp='no'
        echo ' '
        echo ' ******************************************** '
        echo ' *** Error pushing grib files to ftp site *** '
        echo " ***     push_ftp set to $push_ftp        *** "
        echo ' ******************************************** '
        echo ' '
      fi
    fi # blind copy
    
    # rename without the starting "." so it can be found by checksum and ECMWF
    CH_STR="mv ${polardir}/.wave_NCEP_${theDate}${cyc}_prod_fc.grib2 ${polardir}/wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
    $SSH ${USERpolar} $CH_STR
    OK=$?
    checkpoint $OK RENAME_WCOSS >> jcomm_checks.log
    if [ "$OK" != '0' ]
    then
      echo ' '
      echo ' ********************************************** '
      echo ' ***   Error renaming grib2 file on polar   *** '
      echo ' ********************************************** '
	else
      echo ' Renamed file on polar'
	fi # rename file
    
    # Run check sum on data server end 
    OUT_STR="/home/people/emc/waves/bin/check_jcomm_gfswave.sh ${theDate}${cyc} > ckjcommsum.out"
    $SSH ${USERpolar} $OUT_STR
    OK=$?
    checkpoint $OK WCOSS_MD5 >> jcomm_checks.log
    if [ "$OK" != '0' ]
    then
      echo ' '
      echo ' ********************************************** '
      echo ' *** Error running check jcomm sum on polar *** '
      echo ' ********************************************** '
    else
      # copy polar's MD5 file back to devwcoss for comparison
      echo ' copy polars MD5 file back to devwcoss for comparison'
      $SCP ${USERpolar}:${polardir}/wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5 ${workdir}/${theDate}/wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5.polar
      OK=$?
      checkpoint $OK SCP_POLAR_MD5 >> jcomm_checks.log
      
      # compare the two check sums:
      echo ' diff the two check sums'
      diff ${workdir}/${theDate}/wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5 ${workdir}/${theDate}/wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5.polar
      OK=$?
      checkpoint $OK DIFF_MD5 >> jcomm_checks.log
      if [ "$OK" != '0' ]
      then
        echo ' '
        echo ' ************************************* '
        echo ' *** Different checksum from polar *** '
        echo ' ************************************* '
	  else
        echo ' checksums match!'
	  fi # checksums match  
	fi # copy to polar
  fi # push_ftp
  
  rm cat${cyc}.grib2
  rm out${cyc}.grib2
  
  echo "DONE_${cyc}" >> jcomm_checks.log
  echo "***     ***" >> jcomm_checks.log
  
done

# check to make sure the files are on the ftp site:
LS_STR="ls -lh ${polardir}/wave_NCEP_${theDate}*_prod_fc.grib2"
$SSH ${USERpolar} $LS_STR >> jcomm_checks.log

# add data_range.txt to jcomm_checks.log
echo "***     ***" >> jcomm_checks.log
cat all_range.txt >> jcomm_checks.log

# email the jcomm_check.log file
cat jcomm_checks.log | mail -s "JCOMM2 checks" Samira.Ardani@noaa.gov

# clean up
cd ${workdir}
#rm -rf ${workdir}/${theDate}

exit
