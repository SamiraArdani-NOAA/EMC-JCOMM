#!/bin/bash -l
# checkpoint function  usage:  checkpoint $? Name
function checkpoint {
  if (( $1 == 0 )); then
    echo "$2 OK"
  else
    echo "$2 FAILED, RC=$1"
  fi
}


srcdir='/scratch4/NCEPDEV/ovp/Samira.Ardani/JCOMM/scripts'
fixdir='/scratch4/NCEPDEV/ovp/Samira.Ardani/JCOMM/fix'
workdir='/scratch4/NCEPDEV/stmp/Samira.Ardani/JCOMM'
hpsstar='/scratch4/NCEPDEV/ovp/Samira.Ardani/JCOMM/bin/hpsstar'
USERpolar='waves@emcrzdm.ncep.noaa.gov'
polardir='/home/ftp/polar/waves/JCOMM'


SSH=/usr/bin/ssh
SCP=/usr/bin/scp

module purge
module use /scratch4/NCEPDEV/ovp/Samira.Ardani/python_modules/
module load env-Ursa

module load netcdf-c/4.9.2
module load wgrib2/3.1.3_ncep
module load eccodes/2.33.0

md5sum=/bin/md5sum


TODAY=$(date +'%Y%m%d')
theDate=$1
cyc=$2
  
  mkdir -p ${workdir}/${theDate}
  cp ${srcdir}/fix_ranges.py ${workdir}/${theDate}/fix_ranges.py
  cp ${fixdir}/jcomm.rule.filter ${workdir}/${theDate}/rule.filter
  cp ${fixdir}/jcomm.paramIDs.txt ${workdir}/${theDate}/paramIDs.txt
    
  
  pre_clean='yes'
  copy_files='yes'
  prep_file='yes'
  qc_file='yes'
  push_ftp='yes'
  check_ftp='yes'
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
    rm -f ${workdir}/${theDate}/gfswave*.grib2	
  fi
  
echo "running get_hpss_archive for ${theDate}"
yy=`date --date=$theDate "+%Y"`
yymm=`date --date=$theDate "+%Y%m"`
hpssdir=/NCEPPROD/hpssprod/runhistory/rh${yy}/${yymm}/${theDate}

# begin hpss extraction
mkdir -p $workdir
cd ${workdir}

#for cyc in ${cycles}; do
  echo 'processing' $cyc
  hpss_tar=${hpssdir}/com_gfs_v16.3_gfs.${theDate}_${cyc}.gfswave_output.tar
  hpss_files=$( $hpsstar inx $hpss_tar | grep global.0p25 | grep -v idx )
  $hpsstar getnostage $hpss_tar $hpss_files
  
#done

echo "get_hpss_archive finished on `date`"

#cd ${workdir}/gfs.${theDate}/${cyc}/wave/gridded/
if [[ "${copy_files}" = 'yes' ]];then
 cp ${workdir}/gfs.${theDate}/${cyc}/wave/gridded/*.grib2 ${workdir}/${theDate}
fi

cd ${workdir}/${theDate}
    if [[ "${prep_file}" = 'yes' ]]
	then
      OK=0
           for file in gfswave.t${cyc}z.global.0p25.f*.grib2; do	
             wgrib2 $file -s | egrep '(:UGRD:|:VGRD:|:HTSGW:|:PERPW:|:DIRPW:)' | wgrib2 -i $file -append -grib cat${cyc}.grib2
	
	   if (( $? != 0 )); then
            OK=$?
            checkpoint $OK GRIB_FILTER-${file}
           fi
          done
	  checkpoint $OK GRIB_FILTER >> jcomm_checks.log

	  rm -f ${workdir}/${thedate}/gfswave.t${cyc}z.global.0p25.f${FCST}.grib2
	  echo "grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2"

	  grib_filter -o out${cyc}.grib2 rule.filter cat${cyc}.grib2
	  checkpoint $? GRIB_FILTER >> jcomm_checks.log
	  
      module unload eccodes/2.33.0

	  echo "***     ***" >> all_range.txt
	  echo "python fix_ranges.py out${cyc}.grib2"
	  python fix_ranges.py out${cyc}.grib2
	  cat data_range.txt >> all_range.txt
	  echo "***     ***" >> all_range.txt
	  checkpoint $? FIX_RANGES >> jcomm_checks.log
	        
      module load eccodes/2.33.0

	  echo "grib_set -r -s packingType=grid_simple out${cyc}.grib2 wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
	  grib_set -r -s packingType=grid_simple out${cyc}.grib2.fix wave_NCEP_${theDate}${cyc}_prod_fc.grib2
	  checkpoint $? GRIB_SET >> jcomm_checks.log
	  
	  echo "creating MD5 check sum for wave_NCEP_${theDate}${cyc}_prod_fc.grib2"
	  md5sum wave_NCEP_${theDate}${cyc}_prod_fc.grib2 > wave_NCEP_${theDate}${cyc}_prod_fc.grib2.MD5
	  checkpoint $? MD5 >> jcomm_checks.log
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
	  checkpoint $OK SCP >> jcomm_checks.log
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
	  checkpoint $OK RENAME >> jcomm_checks.log
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
	  OUT_STR="/home/people/emc/waves/bin/check_jcomm_gfswave_r2.sh ${theDate}${cyc} > ckjcommsum.out"
	  $SSH ${USERpolar} $OUT_STR
	  OK=$?
	  checkpoint $OK MD5 >> jcomm_checks.log
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
	
	
	echo "DONE_${cyc}" >> jcomm_checks.log
	echo "***     ***" >> jcomm_checks.log
	
  
  if [[ "${check_ftp}" = 'yes' ]]
  then
    # check to make sure the files are on the ftp site:
    LS_STR="ls -lh ${polardir}/wave_NCEP_${theDate}*_prod_fc.grib2"
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
