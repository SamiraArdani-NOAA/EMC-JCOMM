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
# prepare the files for wcoss2 push to polar 
#                                            

set -x

NEWHOME="/lfs/h2/emc/vpppg/noscrub/$USER"
srcdir="$NEWHOME/VPPPG/EMC_waves-prod-gen/JCOMM/scripts"
fixdir="$NEWHOME/VPPPG/EMC_waves-prod-gen/JCOMM/fix"
workdir="/lfs/h2/emc/ptmp/$USER/JCOMM"
datadir='/lfs/h1/ops/prod/com/gfs/v16.3'  ## GFS-Wave prod
#datadir='/lfs/h2/emc/vpppg/noscrub/deanna.spindler/GFS_grib/archive'

SSH=/usr/bin/ssh
SCP=/usr/bin/scp

module list

cycle=$1
theDate=${2:-$(date --date="yesterday" +"%Y%m%d")}
#theDate='20230207'
echo "Running JCOMM for ${theDate}${cycle}"

copy_files='yes'
prep_files='yes'

# match the dir structure from get_hpss_archive.sh
longworkdir="${workdir}/gfs.${theDate}/${cycle}/wave/gridded"
mkdir -p ${longworkdir}
#rm ${workdir}/gfs.${theDate}/jcomm_checks.log

cd ${longworkdir}

if [[ "${copy_files}" = 'yes' ]]
then
  # check if the data is there, prod is kept for 12 days
  touch ${workdir}/gfs.${theDate}/jcomm_checks.log
  rm -f ${longworkdir}/cat${cycle}.grib2
  if [[ -a ${datadir}/gfs.${theDate}/${cycle}/wave/gridded ]]; then
    cp ${datadir}/gfs.${theDate}/${cycle}/wave/gridded/gfswave.t${cycle}z.global.0p25.*.grib2 ${longworkdir}/.
  else
    echo "Need to run get_jcomm_hpss first!"
    echo "Exiting now"
    exit 999
  fi
  checkpoint $? ${cycle} CP_data >> ${workdir}/gfs.${theDate}/jcomm_checks.log
fi # copy file

if [[ "${prep_files}" = 'yes' ]]
then
  OK=0
  for file in gfswave.t${cycle}z.global.0p25.*.grib2; do
    wgrib2 $file -s | egrep '(:UGRD:|:VGRD:|:HTSGW:|:PERPW:|:DIRPW:)' | \
    wgrib2 -i $file -append -grib cat${cycle}.grib2 1> /dev/null
    if (( $? != 0 )); then
      OK=$?
      checkpoint $OK ${cycle} WGRIB2-${file}
    fi
  done
  checkpoint $OK ${cycle} WGRIB2 >> ${workdir}/gfs.${theDate}/jcomm_checks.log  
  # remove the individual grib2 files
  rm -f ${longworkdir}/gfswave.t${cycle}z.global.0p25.*.grib2
fi

echo "DONE_devwcoss2 ${cycle}" >> ${workdir}/gfs.${theDate}/jcomm_checks.log
echo "***      *****      ***" >> ${workdir}/gfs.${theDate}/jcomm_checks.log

exit
