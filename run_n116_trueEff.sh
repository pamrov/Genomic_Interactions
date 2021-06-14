#!/bin/bash

#total num of sim rounds per sample size: 205,379

#SBATCH --qos=preemptable
#SBATCH --ntasks=2
#SBATCH --time=24:00:00
#SBATCH --array=[1-205380:210]
  #Yields 978 directories/task arrays
  #n116 endpt: 205,379
  #JOB ARRAY: START-END:STEP_SIZE
#SBATCH --output=/rc_scratch/paro1093/power_rs169/trueEffect2/slurm/trueEff2-n116-startpt-%a.out

##############
# Notes
##############
  #Job array: corresponds to startRow of combinations to test for each from parat file
  #Total Jobs = 822 total jobs (w/ step of 250) (821 with remainder of 129)
  #225 sims per job task array = 912 sets with 179 sims left over
  #205 sims/job task array = 1,000 sets with 379 sims left over

  #Performance: 12CPUs computed 50 rounds of sim in 3 hrs for noEff run
    #100 rounds in 6 hrs
  #NOTE: Max array length == 1,000 -- limit that UCB-Slurm sets

##############
# 1: Setup
##############
#get job ID & start time:
echo "Slurm Job ID:" ${SLURM_ARRAY_JOB_ID}
start_time=`date +%s`
echo "Start time:" `date +%c`
  #print start time in Day-Month-Yr Time in 24 hr format

#clean environment:
ml purge
ml R/3.5.0

#initialize start index, nsims to run per job array member, & end index
totSimsperN=205379                   #TOTAL NUM SIMS PER SAMPLE SIZE
sind=${SLURM_ARRAY_TASK_ID}          #SLURM ARRAY INDEX
nsims=$(($SLURM_ARRAY_TASK_STEP-1))  #SLURM ARRAY STEP SIZE-1
eind=$(($sind + $nsims))             #TOTAL SIMS TO RUN PER JOB ARRAY MEMBER
endpt=$(($sind + $totSimsperN -1))   #FINAL SIM FOR THIS SAMPLE/BATCH

#make new directory for each set of sims, or fail quietly if it already exists:
mkdir -p /rc_scratch/paro1093/power_rs169/trueEffect2/${sind}

#initialize counter for loop
counter=$sind

##############
# 2: Run Sims
##############
#loop through all samples from sind to eind
while [[ $counter -le $eind ]]
do

 #check for existence of output file for this simulation.
 #if output file already exists, skip this sim
 #this logic is required because we are running preemptively and we want to avoid re-running the same sim in a given set more than once.
 if [[ -f "/rc_scratch/paro1093/power_rs169/trueEffect2/${sind}/trueEff2_n116442_sim_#_${counter}.csv" ]]; then
   echo "sim # ${counter} has already been run. Skipping to next simulation..."
 else
   echo "running sim # ${counter}"
   Rscript /pl/active/IBG/promero/power_rs169/trueEff/run_trueEff_pwr.R ${sind} ${counter} ${endpt}
 fi
 #advance counter:
 counter=$(($counter + 1))
done

echo "Finished with sim set starting at" $sind

#################
# 3: Merge Output
#################

#now concatenate all files in directory into one summary file:
#grab the header line out of the first file in directory:
head -1 /rc_scratch/paro1093/power_rs169/trueEffect2/${sind}/*${sind}.csv > /rc_scratch/paro1093/power_rs169/trueEffect2/summary_n116442_${sind}.csv

#add non-matching (--v) lines to our new summary file (so headers don't repeat):
cat /rc_scratch/paro1093/power_rs169/trueEffect2/${sind}/*.csv |grep -v "sample_size" >> /rc_scratch/paro1093/power_rs169/trueEffect2/summary_n116442_${sind}.csv

##############
# 4: Rundown
##############

echo "Process complete"
echo "Total runtime: $((($(date +%s)-$start_time)/60)) minutes"
