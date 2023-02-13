#!/bin/bash
# 
# run as: get_jcomm_hpss.sh 20221212 20221225
#
# hpsstar dir /NCEPPROD/5year/hpssprod/runhistory/rh2021/202112/20211204
#
# get any missing GFS-Wave files from HPSS
# and put them on /lfs/h2/emc/vpppg/noscrub/deanna.spindler/GFS_grib/archive

NEWHOME='/lfs/h2/emc/vpppg/noscrub/deanna.spindler'
workdir='/lfs/h2/emc/vpppg/noscrub/deanna.spindler/GFS_grib/archive'
hpsstar=$NEWHOME/bin/hpsstar

theDate=$1
endDate=${2:-$1}

cycles='00 06 12 18'
cycles='00'

echo "starting at `date`"
while (( $theDate <= $endDate )); do
  echo "running get_jcomm_hpss for ${theDate}"
  yy=`date --date=$theDate "+%Y"`
  yymm=`date --date=$theDate "+%Y%m"`
  cd ${workdir}
  hpss_dir=/NCEPPROD/hpssprod/runhistory/rh${yy}/${yymm}/${theDate}
  for cyc in $cycles; do
    echo 'processing' $cyc
	tarfile=${hpss_dir}/com_gfs_v16.3_gfs.${theDate}_${cyc}.gfswave_output.tar
    hpssfiles=$(${hpsstar} inx ${tarfile} | grep global.0p25 | grep -v idx)
    # begin hpss extraction
    ${hpsstar} getnostage ${tarfile} ${hpssfiles}
  done
  theDate=$(date --date="$theDate + 1 day" '+%Y%m%d')
done

echo "get_jcomm_hpss finished on `date`"
exit

