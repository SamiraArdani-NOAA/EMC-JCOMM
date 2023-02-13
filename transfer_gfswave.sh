#!/bin/bash

# checkpoint function  usage:  checkpoint $? Name
function checkpoint {
  if (( $1 == 0 )); then
    echo "$2 $3 OK"
  else
    echo "$2 $3 FAILED, RC=$1"
  fi
}

#                                           
# prepare the files for wcoss push to polar 
#                                           

workdir="/lfs/h2/emc/ptmp/$USER/JCOMM"
USERtiggr='dspindler@emc-lw-dspindle'
tiggrdir='/export/emc-lw-dspindle/dspindler/JCOMM2'

SSH=/usr/bin/ssh
SCP=/usr/bin/scp

theDate=$(date --date="yesterday" +"%Y%m%d")
#theDate='20230207'
echo "Transfering JCOMM for ${theDate}"

## must match what is on Tiggr/batch_prepare_gfswave.sh

push_tiggr='yes'
run_tiggr='yes'

cd ${workdir}/gfs.${theDate}
pwd

if [[ "${push_tiggr}" = 'yes' ]]
then
  # make the directory on Tiggr
  mkdircom="mkdir -p ${tiggrdir}/workdir/${theDate}"
  $SSH ${USERtiggr} ${mkdircom}
  
  # copy the cat${cyc}.grib2 files to Tiggr:
  echo "copying the cat*.grib2 to Tiggr"
  $SCP */wave/gridded/cat*.grib2 ${USERtiggr}:${tiggrdir}/workdir/${theDate}/.
  OK=$?
  checkpoint $OK SCP_TIGGR >> ${workdir}/gfs.${theDate}/jcomm_checks.log
  if [[ "$OK" != '0' ]]
  then
    run_tiggr='no'
    echo ' '
    echo ' ******************************************** '
    echo ' *** Error copying grib files to tiggr    *** '
    echo " ***     run_tiggr set to $run_tiggr      *** "
    echo ' ******************************************** '
    echo ' '
    echo ' exiting now '
    exit
  fi # copy
fi # push_tiggr

echo "DONE_devwcoss" >> ${workdir}/gfs.${theDate}/jcomm_checks.log
echo "***     ***" >> ${workdir}/gfs.${theDate}/jcomm_checks.log
scp jcomm_checks.log ${USERtiggr}:${tiggrdir}/workdir/${theDate}/.

if [[ "${run_tiggr}" = 'yes' ]]
then
  # start the script on Tiggr and don't detach WCOSS2
  $SSH ${USERtiggr} ${tiggrdir}/scripts/batch_prepare_gfswave.sh ${theDate} ${cycles}
  OK=$?
  #checkpoint $OK run_tigger >> jcomm_checks.log
  if [ "$OK" != '0' ]
  then
    echo ' '
    echo ' ********************************************** '
    echo ' ***   Error running JCOMM script on tiggr  *** '
    echo ' ********************************************** '
  else
    echo ' JCOMM ran on Tiggr'
  fi # script ran on tiggr  
fi # push_tiggr

# clean up
rm -rf ${workdir}/gfs.${theDate}

exit
