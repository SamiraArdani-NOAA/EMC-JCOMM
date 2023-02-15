# EMC-JCOMM
Prepare the GFS-Wave grib2 files for JCOMM validation project.

Process starts on WCOSS2:
run_jcomm.sh (runs on the cron)

The WCOSS2 part gathers the GFS-Wave data and sends it to the workstation, and submits
Workstation/scripts/batch_prepare_gfswave.sh

Process puts daily GFS-Wave grib2 files in emcrzdm: /home/ftp/polar/waves/JCOMM

At the end of the run, it sends an email with the checkpoints listed so the user can know if the process worked or failed.

Requires from Python: pygrib, numpy, xarray

Requires ecCodes: grib_filter, grib_set, grib_ls

prepare_data_wcoss_eccodes.sh is the original script that used to run completely on the old WCOSS machine.
