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
USERpolar='waves@emcrzdm.ncep.noaa.gov'
polardir='/home/ftp/polar/waves/JCOMM'

SSH=/usr/bin/ssh
SCP=/usr/bin/scp

#export PATH=/export/emc-lw-dspindle/dspindler/anaconda3/envs/work/bin:$PATH

TODAY=$(date +'%Y%m%d')
theDate=${1:-$TODAY}   ## use a passed-in date if given, else use TODAY
cycles=${2:-'00 06 12 18'}
#theDate='20230125'
#cycles=${2:-'18'}
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
  
  #rm cat${cyc}.grib2
  #rm out${cyc}.grib2
  
  echo "DONE_${cyc}" >> jcomm_checks.log
  echo "***     ***" >> jcomm_checks.log
  
done

# clean up
cd ${workdir}
#rm -rf ${workdir}/${theDate}

exit
