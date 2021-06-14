#!/bin/bash

##############
# 1: Setup
##############

#total num of sim rounds: 1,026,895
#total sim rounds per sample size (5 sample sizes tot): 205,379
#(205,379*2)+1 = 410,759 (start point for n=300,000)

#SBATCH --job-name=n300_pwr
#SBATCH --qos=normal
#SBATCH --partition=shas
#SBATCH --ntasks=4
#SBATCH --time=24:00:00
#SBATCH --array=[410759-616140:210]
  #Yields 978 directories/task arrays
  #n300 endpt: 616,137
  #JOB ARRAY: START-END:STEP_SIZE
#SBATCH --output=/scratch/summit/paro1093/power_rs169/trueEffect2/slurm/trueEff-n300-startpt-%a.out

#get start time:
echo "Slurm Job ID:" ${SLURM_ARRAY_JOB_ID}
start_time=`date +%s`
echo "Start time:" `date +%c`
  #print start time in Day-Month-Yr Time in 24 hr format

#clean environment:
ml purge
ml R/3.5.0

#Global to this JOB/SAMPLE SIZE:
#---------------------------------
#get global starting & endpts for this whole job, as well as totSims to run:
totSimsperN=205379                   #TOTAL NUM SIMS PER SAMPLE SIZE
stpt=${SLURM_ARRAY_TASK_MIN}         #START INDEX FOR THIS WHOLE SAMPLE
endpt=$(($stpt + $totSimsperN -1))   #FINAL SIM FOR THIS SAMPLE/BATCH

#Specific to this BATCH:
#------------------------
#initialize start index, nsims to run per job array member, & end index
sind=${SLURM_ARRAY_TASK_ID}          #SLURM ARRAY INDEX
nsims=$(($SLURM_ARRAY_TASK_STEP-1))  #SLURM ARRAY STEP SIZE-1
eind=$(($sind + $nsims))             #TOTAL SIMS TO RUN PER JOB ARRAY MEMBER

#make new directory for each set of sims, or fail quietly if it already exists:
mkdir -p /scratch/summit/paro1093/power_rs169/trueEffect2/${sind}

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
 if [[ -f "/scratch/summit/paro1093/power_rs169/trueEffect2/${sind}/trueEff2_n300000_sim_#_${counter}.csv" ]]; then
   echo "sim # ${counter} has already been run. Skipping to next simulation..."
 else
   echo "running sim # ${counter}"
   Rscript /pl/active/IBG/promero/power_rs169/trueEff/run_trueEff_pwr2.R ${sind} ${counter} ${endpt}
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
head -1 /scratch/summit/paro1093/power_rs169/trueEffect2/${sind}/*${sind}.csv > /scratch/summit/paro1093/power_rs169/trueEffect2/summary_n300000_${sind}.csv

#add non-matching (--v) lines to our new summary file (so headers don't repeat):
cat /scratch/summit/paro1093/power_rs169/trueEffect2/${sind}/*.csv |grep -v "sample_size" >> /scratch/summit/paro1093/power_rs169/trueEffect2/summary_n300000_${sind}.csv

##############
# 4: Rundown
##############

echo "Process complete"
echo "Total runtime: $((($(date +%s)-$start_time)/60)) minutes"
