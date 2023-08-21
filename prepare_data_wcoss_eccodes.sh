#!/bin/bash

# checkpoint function  usage:  checkpoint $? Name
function checkpoint {
  if (( $1 == 0 )); then
    echo "$2 OK"
  else
    echo "$2 FAILED, RC=$1"
  fi
}

#conda activate hera-work
#                                           
# prepare the files for wcoss push to polar 
#                                           

srcdir='/scratch2/NCEPDEV/ovp/Samira.Ardani/JCOMM/scripts'
fixdir='/scratch2/NCEPDEV/ovp/Samira.Ardani/JCOMM/fix'
workdir='/scratch2/NCEPDEV/stmp1/Samira.Ardani/JCOMM/'
hpsstar='/scratch2/NCEPDEV/ovp/Samira.Ardani/JCOMM/bin/hpsstar'
USERpolar='waves@emcrzdm.ncep.noaa.gov'
polardir='/home/ftp/polar/waves/JCOMM-test'
#on Mars and Venus:
# A sample data:
#/NCEPPROD/hpssprod/runhistory/rh2023/202305/20230512/com_gfs_v16.3_gfs.20230512_00.gfswave_output.tar.idx
#datadir='/gpfs/dell1/nco/ops/com/wave/prod'

SSH=/usr/bin/ssh
SCP=/usr/bin/scp
#CDODIR=/gpfs/dell2/emc/verification/noscrub/Todd.Spindler/CDO/bin

#. /usrx/local/prod/lmod/lmod/init/profile
module purge
module load hpss
module load intel/17.0.5.239
module load wgrib2/2.0.8

grib_filter=/scratch2/NCEPDEV/ovp/Samira.Ardani/Samira_apps/miniconda3/envs/hera-work/bin/grib_filter
grib_set=/scratch2/NCEPDEV/ovp/Samira.Ardani/Samira_apps/miniconda3/envs/hera-work/bin/grib_set
grib_count=/scratch2/NCEPDEV/ovp/Samira.Ardani/Samira_apps/miniconda3/envs/hera-work/bin/grib_count
grib_ls=/scratch2/NCEPDEV/ovp/Samira.Ardani/Samira_apps/miniconda3/envs/hera-work/bin/grib_ls
md5sum=/bin/md5sum
#module load EnvVars/1.0.3 ips/18.0.1.163   # needed to get grib_util to load
#module load grib_util/1.2.4                # for $WGRIB2
#module use -a /gpfs/dell1/usrx/local/nceplibs/dev/modulefiles
#module load eccodes/2.17.0

#module load intel/2022.3.0
#module load gnu/9.2.0
#module load wgrib2/3.1.1_wmo
#module load grib_api/1.26.1
#module load eccodes/2.8.2


TODAY=$(date +'%Y%m%d')
#theDate=${1:-$TODAY}   ## use a passed-in date if given, else use TODAY
theDate=$1
#cycles={$2:-'00 06 12 18'}
#echo $theDate
#endDate=${2:-$theDate}
#yy=`date --date=theDate "+%Y%m"`
#yymm=`date --date=theDate "+%Y%m"`

# These upcoming line are used in WCOSS2:
#echo "Running on ${SITE}"
#typeset -u DEV=$(cat /etc/dev)
#echo "DEV is $DEV"

#typeset -u DEV=$(cat /etc/dev)
#if [ $SITE == $DEV ]; then
#  runcron=1
#  echo "DEV is $DEV, and running on $SITE"
#else
#  runcron=0
#  echo "DEV is $DEV, cannot run on $SITE"
#  exit
#fi

#if [ $runcron -eq 1 ]; then
  
  mkdir -p ${workdir}/${theDate}
  cp ${srcdir}/fix_ranges.py ${workdir}/${theDate}/fix_ranges.py
  cp ${fixdir}/jcomm.rule.filter ${workdir}/${theDate}/rule.filter
  cp ${fixdir}/jcomm.paramIDs.txt ${workdir}/${theDate}/paramIDs.txt
    
  #cycles='00 06 12 18'
  cycles='00'
  
  pre_clean='yes'
  copy_files='yes'
  prep_file='yes'
  qc_file='yes'
  push_ftp='no'
  check_ftp='no'
  clean_up='no'
  
  cd ${workdir}/${theDate}
  touch jcomm_checks.log
  touch all_range.txt
  
  if [[ "${pre_clean}" = 'yes' ]]
  then
    rm -f ${workdir}/${theDate}/jcomm_checks.log
    rm -f ${workdir}/${theDate}/cat*.grib2
    rm -f ${workdir}/${theDate}/out*.grib2
    rm -f ${workdir}/${theDate}/wave*.grib2*
  fi
  
#  for cyc in ${cycles}
#    do
#	if [[ "${copy_files}" = 'yes' ]]
#    then
      # check if the data is there, prod is kept for 12 days
#	  if [[ -a ${datadir}/multi_1.${theDate} ]]; then
#        cp ${datadir}/multi_1.${theDate}/multi_1.glo_30m.t${cyc}z.*.grib2 ${workdir}/${theDate}/.
#      else
#        ${srcdir}/get_hpss_archive.sh ${theDate} ${cyc}
#      fi
#      checkpoint $? CP_data >> jcomm_checks.log
#    fi # copy file

# Added to extract data from HPSS:
#theDate=$1
cycles='00'

echo "running get_hpss_archive for ${theDate}"
yy=`date --date=$theDate "+%Y"`
yymm=`date --date=$theDate "+%Y%m"`
hpssdir=/NCEPPROD/hpssprod/runhistory/rh${yy}/${yymm}/${theDate}

# begin hpss extraction
mkdir -p $workdir
cd ${workdir}

for cyc in ${cycles}; do
  echo 'processing' $cyc
  hpss_tar=${hpssdir}/com_gfs_v16.3_gfs.${theDate}_${cyc}.gfswave_output.tar
  hpss_files=$( $hpsstar inx $hpss_tar | grep global.0p25 | grep -v idx )
  $hpsstar getnostage $hpss_tar $hpss_files
  
done

echo "get_hpss_archive finished on `date`"

#cd ${workdir}/gfs.${theDate}/${cyc}/wave/gridded/
if [[ "${copy_files}" = 'yes' ]];then
 cp ${workdir}/gfs.${theDate}/${cyc}/wave/gridded/*.grib2 ${workdir}/${theDate}
fi

cd ${workdir}/${theDate}
#exit

#while (( $theDate <= $endDate )); do
#  echo "running get_hpss_prod for ${theDate}"
#  yy=$(date --date=$theDate "+%Y")
#  yymm=$(date --date=$theDate "+%Y%m")
# for cyc in $cycles; do
#    echo 'processing' $cyc
#        filedir=${theDate}/${cyc}
#        #mkdir -p ${theDate}
#        griddedDir=gfs.${filedir}/wave/gridded
#        #stationDir=gfs.${filedir}/wave/station
#        hpss_dir=/NCEPPROD/hpssprod/runhistory/rh${yy}/${yymm}/${theDate}
#        hpss_file=${hpss_dir}/com_gfs_v16.3_gfs.${theDate}_${cyc}.gfswave_output.tar
#        fcst=0
#        while (( $fcst <= 23 )); do
#          FCST=$(printf '%03d' $fcst)
#          file=gfswave.t${cyc}z.global.0p25.f${FCST}.grib2
#          $hpsstar getnostage $hpss_file ./$griddedDir/$file
#          fcst=$(($fcst + 1))
#        done
# done
# theDate=$(date --date="$theDate + 1 day" '+%Y%m%d')
 
#fcst=0
#FCST=$(printf '%03d' $fcst)
    if [[ "${prep_file}" = 'yes' ]]
	then
      OK=0
	  #for file in multi_1.glo_30m.t*${cyc}z.*.grib2; do
	 # for file in gfswave.t${cyc}z.global.0p25.f${FCST}.grib2; do
           for file in gfswave.t${cyc}z.global.0p25.f*.grib2; do	
             #wgrib2 -s | egrep '(:UGRD:|:VGRD:|:HTSGW:|:PERPW:|:DIRPW:)' | \
	     #-append -grib cat${cyc}.grib2 1> /dev/null
             wgrib2 $file -s | egrep '(:UGRD:|:VGRD:|:HTSGW:|:PERPW:|:DIRPW:)' | wgrib2 -i $file -append -grib cat${cyc}.grib2
	
	   if (( $? != 0 )); then
            OK=$?
            checkpoint $OK GRIB_FILTER-${file}
           fi
          done
	  checkpoint $OK GRIB_FILTER >> jcomm_checks.log

	#  if [[ -a ${workdir}/${theDate}/cat${cyc}.grib2 ]]; then
	  # remove the individual grib2 files
#	  rm -f ${workdir}/${theDate}/multi_1.glo_30m.t${cyc}z.*.grib2
	  rm -f ${workdir}/${thedate}/gfswave.t${cyc}z.global.0p25.f${FCST}.grib2
	  # change the shortName for each variable:
	  echo "grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2"

	  grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2
	  checkpoint $? GRIB_FILTER >> jcomm_checks.log
	  
#      module unload eccodes/2.17.0
#      module load python/3.6.3
#      export PYTHONPATH=/gpfs/dell2/emc/modeling/noscrub/gwv/py/lib/python:/usrx/local/nceplibs/dev/lib/pygrib/lib/python3.6/site-packages/

      # fix the primary wave period range and create data_range.txt
	  echo "***     ***" >> all_range.txt
	  echo "python fix_ranges.py out${cyc}.grib2"
	  python fix_ranges.py out${cyc}.grib2
	  cat data_range.txt >> all_range.txt
	  echo "***     ***" >> all_range.txt
	  checkpoint $? FIX_RANGES >> jcomm_checks.log
	        
 #     module unload python/3.6.3
 #     module use -a /gpfs/dell1/usrx/local/nceplibs/dev/modulefiles
 #     module load eccodes/2.17.0

      # change the compression to simple (from jpeg2000)
	  echo "grib_set -r -s packingType=grid_simple out${cyc}.grib2 wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
	  grib_set -r -s packingType=grid_simple out${cyc}.grib2.fix wave_NCEP_${theDate}${cyc}_prod_fc.grib2
	  checkpoint $? GRIB_SET >> jcomm_checks.log
	  
	  # create MD5 check sum for wave_NCEP_${theDate}${cyc}_prod_fc.grib
	  echo "creating MD5 check sum for wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
	  md5sum wave_NCEP_${theDate}${cyc}_prod_fc.grib2 > wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5
	  checkpoint $? MD5 >> jcomm_checks.log
   #   fi # cat	  
    fi # prep_file
 
    if [[ "${qc_file}" = 'yes' ]]
	then
      # check number of messages
	  num_messages=`grib_count wave_NCEP_${theDate}${cyc}_prod_fc.grib2`
	  OK=$?
	  checkpoint $OK NUM_MESS >> jcomm_checks.log
	  if [ "${num_messages}" != 705 ]
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
      # blind copy (add "." to start of filename) it to the ftp site for JCOMM:
	  echo "copying wave_NCEP_${theDate}${cyc}_prod_fc.grib2 to Polar"
	  $SCP wave_NCEP_${theDate}${cyc}_prod_fc.grib2 ${USERpolar}:${polardir}/.wave_NCEP_${theDate}${cyc}_prod_fc.grib2
	  OK=$?
	  checkpoint $OK SCP_WCOSS >> jcomm_checks.log
	  if [[ "$OK" != '0' ]]
	  then
        push_ftp='no'
		echo ' '
		echo ' ******************************************** '
		echo ' *** Error pushing grib files to ftp site *** '
		echo " ***     push_ftp set to $push_ftp        *** "
		echo ' ******************************************** '
		echo ' '
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
	  OUT_STR="/home/people/emc/waves/bin/check_jcomm_sum.sh ${theDate}${cyc} > ckjcommsum.out"
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
	
	#rm cat${cyc}.grib2
	#rm out${cyc}.grib2
	
	echo "DONE_${cyc}" >> jcomm_checks.log
	echo "***     ***" >> jcomm_checks.log
	
  #done
  
  if [[ "${check_ftp}" = 'yes' ]]
  then
    # check to make sure the files are on the ftp site:
    LS_STR="ls ${polardir}/wave_NCEP_${theDate}*_prod_fc.grib2"
    $SSH ${USERpolar} $LS_STR >> jcomm_checks.log
    
    # add data_range.txt to jcomm_checks.log
    echo "***     ***" >> jcomm_checks.log
    cat all_range.txt >> jcomm_checks.log
    
    # email the jcomm_check.log file
    cat jcomm_checks.log | mail -s "JCOMM checks" Samira.Ardani@noaa.gov
  fi
  
  if [[ "${clean_up}" = 'yes' ]]
  then
    # clean up
    cd ${workdir}
    rm -rf ${workdir}/${theDate}
  fi
  
#fi  ## on DEV
exit
