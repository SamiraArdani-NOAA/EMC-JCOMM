#!/bin/bash

#------------------------------------------------
# Prepare the GFS-Wave files for JCOMM           
# using the compute nodes                        
# Deanna Spindler                                
# 13 June 2022                                   
#------------------------------------------------

SRCDIR=/path/to/JCOMM/scripts
WORKDIR=/path/to/workdir
cd ${WORKDIR}

job1=$(qsub ${SRCDIR}/jcomm_00.pbs)
job2=$(qsub ${SRCDIR}/jcomm_06.pbs)
job3=$(qsub ${SRCDIR}/jcomm_12.pbs)
job4=$(qsub ${SRCDIR}/jcomm_18.pbs)
# upon successfull completion, push to workstation and run it there
cd ${SRCDIR}
qsub -W depend=afterok:${job1}:${job2}:${job3}:${job4} ${SRCDIR}/transfer_jcomm.pbs
#qsub -W depend=afterok:${job2} ${SRCDIR}/transfer_jcomm.pbs

