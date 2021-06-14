#############################
#0: Read Packages & Functions
#############################

#0.1: every time:
library(future)
library(iterators) #required for foreach
library(parallel) #required for foreach
library(foreach) # setting up environment to use multiple cores
library(data.table)
library(doMC)
registerDoMC(cores=4)

#0.2: read R script with the functions we've created:
source("/pl/active/IBG/promero/power_rs169/funct_pwr.R")

#to run locally: source("/Users/PNR/work/power_rs169/funct_pwr.R")

##############################
#1: Read/Set Parameters
##############################

########## 1-1: Read changing parameters ##############

#1.1.1: read master parameter file:
#----------------------------------
#DONE: move this file to /pl/active so I can read it while running via either Summit or Blanca.
allParats_trueEff <- read.table("/pl/active/IBG/promero/power_rs169/trueEff/master_ALL_trueEff_simParats.txt", header=T)

#to run locally: allParats <- read.table("/Users/PNR/work/power_rs169/trueEff/master_ALL_trueEff_simParats.txt")

#turn into dataframe just in case:
allParats_trueEff <- as.data.frame(allParats_trueEff)
  #note: num_ppl is a double here.

#turn num_ppl into integer (can't have decimal number of ppl):
allParats_trueEff$num_ppl <- as.integer(allParats_trueEff$num_ppl)

#DONE: might want to add if stmt's here to change what subset is created based on the job array: sorted so slurm tasks align with rows in parameter file.

#1.1.2: sort by sample size/align with slurm task array:
#--------------------------------------------------------
#sort by sample size so it's correctly ordered for the slurm task array (205,379 sim rounds per sample/batch):
allParats <- allParats_trueEff[order(allParats_trueEff$num_ppl),]


####### 1-2: Set # of rounds and # of sims per round ###########

#total # of rounds of sims to run for EACH sample size:
totSims <- 205379
  #this only changes when running 1+ sample size at a time

#NOTE: We're running 1 round at a time here, then concat results of sets of 250 into a summary file. Afterwards, we will combine all results into a master file.
#in this case, the number of rounds of sims/number of parat combinations we will do in one task is the same as number of reps for each round
nrounds <- 0 #number of sims to run every time this script runs
nrep <- 1000 #number of iterations of each simulation

#1.2.2: Command line Arguments:
#--------------------------------
#read in a command line argument that contains the index you wish to start at:
args = commandArgs(trailingOnly=TRUE)
#give error if 2 arguments aren't provided:
if (length(args)<3) {
  stop("three arguments for current index and start index of simSet must be supplied", call.=FALSE)
} else if (length(args)==3) {
  # default output file
  #starting point / slurm task array:
  simSet_startpt <- as.integer(args[1])
  #counter:
  simID <- as.integer(args[2])
  #total endpoint: (this is the point at which all sims for that sample size have been run)
  totEndpt <- as.integer(args[3])
}
print(paste("start index", simSet_startpt, sep=" "))

#make sure you don't exceed the number of sample in the input file
# if (startpt == totSims-nrounds){
#   endpt <- totSims
# } else if (startpt > totSims-nrounds) {
#   stop("No more samples to process")
# }else{
#   endpt <- startpt + nrounds
# }

if (simID > totEndpt) {
  stop("All done! No more sims to run")
}

########## 1-3: Set Static Parameters #################

  #rs169:
#-----------
rs169_b <- 0.494289 #estimated from own data
  #0.0745  #from GSCAN supp. table 22 (CPD are binned)

rs169_maf <- 0.34 #rs16969968 A allele freq (risk allele)

  #pheno:
#---------
avg.cpd <- 18.22263 #from own data/UKB
#18.22263
sd.cpd <- 10.16071 #from own dat/UKB

   #ixn
#--------
#betas.avg <- NULL


############# 2: Sim True Effect  ###############

trueEffect.pow.result <- foreach(rowPar=simID, .combine=rbind, .errorhandling="pass")%do%{
  #assign parameters from the rowPar nth row to simulate this combination of parameters:
  np = allParats[rowPar, 1] #num_ppl
  SNPj_beta= allParats[rowPar, 2] #main effect for SNPj
  SNPj_maf = allParats[rowPar, 3] #freq of SNPj in our sample
  ixn_beta = allParats[rowPar, 4] #ixn effect/beta

  #print to see which round of simulations currently working on:
  print(paste("working on true effect sim round #", rowPar, "of:", totEndpt, sep=" "))
  #print % of way done for THIS ROUND OF SIMS:
  batch_progress <- ((rowPar - simSet_startpt)/210)*100
  batch_progress <- round(batch_progress, digits = 2)
  print(paste( batch_progress,"% of sims for this batch complete!", sep=" "))
  #print % way done for WHOLE SAMPLE SIZE:
  total_progress <- ((rowPar/totEndpt)*100)
  total_progress <- round(total_progress, digits = 2)
  print(paste( total_progress,"% of ALL sims for this sample complete!", sep=" "))

  #Now run nreps of simulation with these parameters:
  pow.sim <- foreach(i=1:nrep, .combine=rbind, .errorhandling="stop")%dopar%{
    #1: simulate genotypes:
    genos <- simGenos(np, rs169_b, rs169_maf, SNPj_beta, SNPj_maf)
    #returns: (cbind(rs169, SNPj, ixn))

    #2: simulate trait & create dataframe by binding genos & phenos together:
    cpd.data <- simCPD(np, avg.cpd, sd.cpd, genos$rs169, rs169_b, genos$SNPj, SNPj_beta, genos$ixn, ixn_beta)
    #returns: (cpd.data with pheno + genos)

    #3: run a regression model to see our power to detect ixn in our simulated data:
    cpd.model <- model(cpd.data)
    #returns: (bep): all estimated betas and p-vals
  } #end of foreach running nreps of simulations
  tabulate(np, SNPj_beta, SNPj_maf, ixn_beta, pow.sim)
  #returns: row.tab: average betas and p-values for each round of sims
} #end of foreach running each round of simulations

######## 3: Table Results for true Effect ##########
print(paste("Writing results from sim #", simID, "to file", sep=" "))

write.table(trueEffect.pow.result,paste("/scratch/summit/paro1093/power_rs169/trueEffect2/",simSet_startpt,"/trueEff2_n", np, "_sim_#_",simID,".csv", sep=""),sep=",",col.names=TRUE,row.names=FALSE)
