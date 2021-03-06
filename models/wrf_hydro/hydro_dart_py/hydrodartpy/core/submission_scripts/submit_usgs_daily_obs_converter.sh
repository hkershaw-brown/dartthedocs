#!/bin/bash

#PBS -N JOB_NAME_TEMPLATE
#PBS -e JOB_NAME_TEMPLATE.stderr
#PBS -o JOB_NAME_TEMPLATE.stdout
#PBS -l PBS_SELECT_TEMPLATE
#PBS -l WALLTIME_TEMPLATE
#PBS -A ACCOUNT_TEMPLATE
#PBS -q QUEUE_TEMPLATE
#PBS -m EMAIL_WHEN_TEMPLATE
#PBS -M EMAIL_WHO_TEMPLATE

python create_usgs_daily_obs_seq.py >& JOB_NAME_TEMPLATE.py.stdeo
rm -rf WAIT_FILE_TEMPLATE

exit 0
