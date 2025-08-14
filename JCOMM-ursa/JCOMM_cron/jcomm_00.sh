#!/bin/bash

module use /contrib/spack-stack/spack-stack-1.9.1/envs/ue-oneapi-2024.2.1/install/modulefiles/Core
module load stack-oneapi/2024.2.1
module load stack-intel-oneapi-mpi/2021.13
module use /scratch4/NCEPDEV/ovp/Samira.Ardani/python_modules/
module load env-Ursa
#module use /scratch4/NCEPDEV/marine/Saeideh.Banihashemi/installs/python-modules/
#module load Ursa_ENV

when=$1
#today=$(date +%Y%m%d)
sdate=$(date --date="2 days ago" +%Y%m%d)
# JCOMM
NEWHOME=/scratch4/NCEPDEV/ovp/Samira.Ardani
${NEWHOME}/JCOMM-ursa/JCOMM_cron/prepare_data_wcoss_eccodes.sh $sdate 00 1>${NEWHOME}/JCOMM-ursa/Logs/JCOMM_00.log  2>&1
${NEWHOME}/JCOMM-ursa/JCOMM_cron/prepare_data_wcoss_eccodes.sh $sdate 06 1>${NEWHOME}/JCOMM-ursa/Logs/JCOMM_06.log  2>&1
${NEWHOME}/JCOMM-ursa/JCOMM_cron/prepare_data_wcoss_eccodes.sh $sdate 12 1>${NEWHOME}/JCOMM-ursa/Logs/JCOMM_12.log  2>&1
${NEWHOME}/JCOMM-ursa/JCOMM_cron/prepare_data_wcoss_eccodes.sh $sdate 18 1>${NEWHOME}/JCOMM-ursa/Logs/JCOMM_18.log  2>&1

exit

