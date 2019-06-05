#!/bin/bash 

export USER_EMAIL_ADDRESS=szczypka.wojciech@gmail.com
export CURRENT_GRANT_ID=tm2

function wread_case {
    echo "${PWD##*/}"
}

function wread_kpt {
    local CASE=$1
    local KPT=`awk 'FNR == 1 {print $9}' $CASE.klist`
    echo $KPT
}
 
function wread_rkm {
    local CASE=$1
    local RKM=''
    if [ -e $CASE.in1 ] 
    then
	export RKM=`awk 'FNR == 2 {print $1}' $CASE.in1 | tr -d . ` 
    elif [ -e $CASE.in1c ] 
    then
	export RKM=`awk 'FNR == 2 {print $1}' $CASE.in1c | tr -d . ` 
    fi
    echo $RKM
}

function wread_xc {
    local CASE=$1
    local XC_FROM_IN0=`awk 'FNR == 1 {print $2}' $CASE.in0`
    
    case $XC_FROM_IN0 in 
	XC_PBESOL) local XC="pbs" ;; 
	XC_LDA) local XC="lda" ;; 
	XC_PBE) local XC="pbe" ;; 
	XC_WC) local XC="wc" ;;
	XC_MBJ) local XC="mbj" ;; 
	XC_REVTPSS) local XC="tpss" ;; 
    esac
    
    echo $XC
}

function wread_last_step {
    local STEP_ARRAY=$(find -maxdepth 1 -type d -name "rkm*" | sed 's/_/ /g' | awk '{print $4}')
    local LAST='00'
    for CURRENT in $STEP_ARRAY
    do
	if [ $CURRENT -gt $LAST ]
	then
	    LAST=$CURRENT
	fi
    done
    echo $LAST
}

function wread_all {
    local CASE=$(wread_case)
    echo "Case name: $CASE"
    local KPT=$(wread_kpt $CASE)
    echo "Number of k-points: $KPT"
    local RKM=$(wread_rkm $CASE)
    echo "Rk-max: $RKM"
    local XC=$(wread_xc $CASE)
    echo "XC potential: $XC"
    local LAST_STEP=$(wread_last_step)
    echo "Last step no.: $LAST_STEP"
    local NEXT_STEP=$(($LAST_STEP+1))
    local NEXT_STEP=$(printf "%02d" $NEXT_STEP)
    echo "Next step will be: $NEXT_STEP"
    echo "Name of next dir then: rkm"$RKM"_"$KPT"k_"$XC"_"$NEXT_STEP"_"
}

export -f wread_all

function save_next {
    local CASE=$(wread_case)
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step | sed "s/^0*//")
    local NEXT_STEP=$(($LAST_STEP+1))
    local NEXT_STEP=$(printf "%02d" $NEXT_STEP)
    local SAVE_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$NEXT_STEP"_"
    
    case "$1" in
    eos)
	local SAVE_NAME=$SAVE_NAME"eos"
	mkdir $SAVE_NAME
	mv *_vol_* ./$SAVE_NAME/
	mv *.outputeos ./$SAVE_NAME/
	mv *.vol ./$SAVE_NAME/
	;;
    *)
	save_lapw -d $SAVE_NAME$1
	;;
    esac
    
    
}

export -f save_next

function restore_zero {
    local CASE=$(wread_case)
    local RES_NAME=$CASE"_vol____0.00"
    restore_lapw -f $RES_NAME
}

function restore_last {
    local CASE=$(wread_case)
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step)
    local RES_DIR_PREFIX="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
    
    RES_DIR_SUFFIX=$(find . -name ${RES_DIR_PREFIX}* -type d | awk -F "${RES_DIR_PREFIX}" '{print $2}')
    RES_DIR=$RES_DIR_PREFIX$RES_DIR_SUFFIX
    
    echo 'Restoring from: '$RES_DIR
    
    if [ "${RES_DIR_SUFFIX}" = "eos" ]
    then
	find . -type f -wholename "./$RES_DIR/${CASE}_vol____0.00.*" -exec cp {} ./ \;
	restore_lapw -f ${CASE}_vol____0.00
	rm ${CASE}_vol____0.00.*
    else
	restore_lapw -f -d $RES_DIR
    fi
}

function retrieve_zero {
    local CASE=$(wread_case)
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step)
    local LAST_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
    local ARRAY_ENDS=$(find -type f -wholename "./$LAST_NAME*/*" | sed 's/\./ /g' | awk '{print $2}')
    for CURRENT in $ARRAY_ENDS
    do
	local SRC='./'$LAST_NAME'*/'$CASE'.'$CURRENT
	local DEST='./'$CASE'_vol____0.00.'$CURRENT
	cp $SRC $DEST
    done
}

export -f retrieve_zero

function calc_vol {
    CASE_VOL=$1
    
    local PARAM_A=$(awk 'FNR == 4 {print $1}' $CASE_VOL.struct)
    local PARAM_B=$(awk 'FNR == 4 {print $2}' $CASE_VOL.struct)
    local PARAM_C=$(awk 'FNR == 4 {print $3}' $CASE_VOL.struct)
    local PARAM_AL_DEG=$(awk 'FNR == 4 {print substr($0, 31, 10) }' $CASE_VOL.struct) #'
    local PARAM_BT_DEG=$(awk 'FNR == 4 {print substr($0, 41, 10) }' $CASE_VOL.struct) #'
    local PARAM_GM_DEG=$(awk 'FNR == 4 {print substr($0, 51, 10) }' $CASE_VOL.struct) #'
    local PARAM_AL=$(bc <<< "scale=10; $PARAM_AL_DEG / 180 * 3.1415926536")
    local PARAM_BT=$(bc <<< "scale=10; $PARAM_BT_DEG / 180 * 3.1415926536")
    local PARAM_GM=$(bc <<< "scale=10; $PARAM_GM_DEG / 180 * 3.1415926536")
    
    local VOL1=$(bc -l <<< "scale=10; $PARAM_A * $PARAM_B * $PARAM_C * sqrt(1 + 2 * c($PARAM_AL) * c($PARAM_BT) * c($PARAM_GM) - c($PARAM_AL)^2 - c($PARAM_BT)^2 - c($PARAM_GM)^2 ) " ) #"

#    local BRAVAIS=$(awk 'FNR == 2 {print $1}' $CASE_VOL.struct)
#    case $BRAVAIS in
#	P)  ;;
#	F) local VOL1=$(bc <<< "scale=5; $VOL1 / 4") ;;
#	I) local VOL1=$(bc <<< "scale=5; $VOL1 / 2") ;;
#	A) local VOL1=$(bc <<< "scale=5; $VOL1 / 2") ;;
#	B) local VOL1=$(bc <<< "scale=5; $VOL1 / 2") ;;
#	C) local VOL1=$(bc <<< "scale=5; $VOL1 / 2") ;;
#	R) local VOL1=$(bc <<< "scale=5; $VOL1 / 3") ;;
#    esac
    if [ "$2" = '-v' ]
    then
	echo "a: $PARAM_A, b: $PARAM_B, c: $PARAM_C"
	echo "alpha: $PARAM_AL_DEG, beta: $PARAM_BT_DEG, gamma: $PARAM_GM_DEG"
    fi
    
    echo "${VOL1}"
}

function prep_opt {
    local CASE=$(wread_case)
    if [ -e ${CASE}_initial.struct ]
    then
	rm ${CASE}_initial.struct
    fi
    
    printf "1\n4\n-5\n-2.5\n2.5\n5\n" | x optimize
    
    sed -i -e "s/ run_lapw -ec 0.0001   #/run_lapw -ec 0.0001 -p   #/g" optimize.job
    sed -i -e "s/_default/ /g" optimize.job 
    
}

export -f prep_opt

function prep_dos {
    local CASE=$(wread_case)
    
    local DOS_DIR='DOS/'$CASE
    
    mkdir DOS
    mkdir $DOS_DIR
    
    cp .job_config $DOS_DIR/.job_config
    cp .machines $DOS_DIR/.machines
    
    echo 'DOS directory has been created.'
    
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step)
    local LAST_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
    local ARRAY_ENDS=$(find -type f -wholename "./$LAST_NAME*/*" | sed 's/\./ /g' | awk '{print $2}')
    for CURRENT in $ARRAY_ENDS
    do
	local SRC=$LAST_NAME'*/'$CASE'.'$CURRENT
	local DEST=$DOS_DIR'/'$CASE'.'$CURRENT
	cp $SRC $DEST
	echo "File $SRC copied to DOS directory ($DEST)."
    done
    
    echo 'DOS directory is ready to run the calculations (" x kgen; x lapw0; x lapw1 -p; x lapw2 -qtl -p", etc.). Remember to adjust .machines and .job_config files to your needs!'
} 

export -f prep_dos

function prep_bs {
    local CASE=$(wread_case)
    
    local BS_DIR='BS/'$CASE
    if [ -d BS ]
    then
	local COUNT=0
	for DIR in `find -type d -name 'BS*'`
	do
	    local COUNT=$((COUNT+1))
	done
	mv BS BS_old$COUNT
    fi
    
    mkdir BS
    mkdir $BS_DIR
    
    cp .job_config $BS_DIR/.job_config
    cp .machines $BS_DIR/.machines
    
    echo 'BS directory has been created.'
    
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step)
    local LAST_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
    local ARRAY_ENDS=$(find -type f -wholename "./$LAST_NAME*/*" | sed 's/\./ /g' | awk '{print $2}')
    for CURRENT in $ARRAY_ENDS
    do
	local SRC=$LAST_NAME'*/'$CASE'.'$CURRENT
	local DEST=$BS_DIR'/'$CASE'.'$CURRENT
	cp $SRC $DEST
	echo "File $SRC copied to BS directory ($DEST)."
    done
    
    if [ -n "$1" ]
    then
	cp "$HOME/klist_band_templates/$1.klist_band" $BS_DIR"/$CASE.klist_band"
	echo "Template of klist_band file for symmetry group $1 has been copied to BS directory." 
    fi
    
    echo 'BS directory is ready to run the calculations ("x lapw1 -band -p; x lapw2 -qtl -band -p", etc.). Remember to adjust .machines and .job_config files to your needs!'
} 

export -f prep_bs

function prep_rho {
    local CASE=$(wread_case)
    
    local RHO_DIR='RHO/'$CASE
    
    mkdir RHO
    mkdir $RHO_DIR
    
    cp .job_config $RHO_DIR/.job_config
    cp .machines $RHO_DIR/.machines
    
    echo 'RHO directory has been created.'
    
    # copying necessary files from previous calcs
    local KPT=$(wread_kpt $CASE)
    local RKM=$(wread_rkm $CASE)
    local XC=$(wread_xc $CASE)
    local LAST_STEP=$(wread_last_step)
    local LAST_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
    local ARRAY_ENDS=$(find -type f -wholename "./$LAST_NAME*/*" | sed 's/\./ /g' | awk '{print $2}')
    for CURRENT in $ARRAY_ENDS
    do
	local SRC=$LAST_NAME'*/'$CASE'.'$CURRENT
	local DEST=$RHO_DIR'/'$CASE'.'$CURRENT
	cp $SRC $DEST
	echo "File $SRC copied to RHO directory ($DEST)."
    done
    
    # change Gmax to 20
    NEW_GMAX='20.00'
    if [ -e $RHO_DIR/$CASE.in2 ]
    then
	GMAX_LINE=$(grep -n 'GMAX' $RHO_DIR/$CASE.in2 | awk -F ':' '{print $1}')
	OLD_GMAX=$(grep -n 'GMAX' $RHO_DIR/$CASE.in2 | awk '{print $2}')
	sed -i "${GMAX_LINE}s/$OLD_GMAX/$NEW_GMAX/" $RHO_DIR/$CASE.in2
	echo "GMAX value in $CASE.in2 has been increased to 20.0 ."
    elif [ -e $RHO_DIR/$CASE.in2c ]
    then
	GMAX_LINE=$(grep -n 'GMAX' $RHO_DIR/$CASE.in2c | awk -F ':' '{print $1}')
	OLD_GMAX=$(grep -n 'GMAX' $RHO_DIR/$CASE.in2c | awk '{print $2}')
	sed -i "${GMAX_LINE}s/$OLD_GMAX/$NEW_GMAX/" $RHO_DIR/$CASE.in2c
	echo "GMAX value in $CASE.in2c has been increased to 20.0 ."
    fi
    
    # change NR2V to R2V to generate .vtotal file
    if [ -e $RHO_DIR/$CASE.in0 ]
    then
	sed -i "2s/^NR2V/R2V /" $RHO_DIR/$CASE.in0
	echo "NR2V changed to R2V in $CASE.in0 to generate .vtotal file."
    elif [ -e $RHO_DIR/$CASE.in0c ]
    then
	sed -i "2s/^NR2V/R2V /" $RHO_DIR/$CASE.in0c
	echo "NR2V changed to R2V in $CASE.in0c to generate .vtotal file."
    fi
    
    
    echo 'RHO directory is ready to run the calculations. Remember to adjust .machines and .job_config files to your needs!'
} 

export -f prep_rho

function check_pressure_zero {
    local CASE=$(wread_case)
    
    if [ -e $CASE.outputeos ]
    then
	local BM_POS=$(grep -n 'Equation of state: Birch-Murnaghan' $CASE.outputeos | awk -F ':' '{print $1}')
	local VOL0_POS=$((BM_POS+4))
	local VOL0=$(awk "FNR == $VOL0_POS {print \$2}" $CASE.outputeos)
	local B0=$(awk "FNR == $VOL0_POS {print \$3}" $CASE.outputeos)
	local BP=$(awk "FNR == $VOL0_POS {print \$4}" $CASE.outputeos)
    else
	# create new .vol file for x eosfit
	if [ -e $CASE.vol ]
	then
	    rm $CASE.vol
	fi
	for SCF_FILE in `ls *_vol_*.scf`
	do
	    local ENE_part=`grepline :ENE $SCF_FILE 1 | tail -n +2 | awk '{print $NF}'`
	    local VOL_part=`grepline :VOL $SCF_FILE 1 | tail -n +2 | awk '{print $NF}'`
	    echo "  $VOL_part   $ENE_part" >> $CASE.vol
	done
	printf 'Y\n0\n' | x eosfit 
	local BM_POS=$(grep -n 'Equation of state: Birch-Murnaghan' $CASE.outputeos | awk -F ':' '{print $1}')
	local VOL0_POS=$((BM_POS+4))
	local VOL0=$(awk "FNR == $VOL0_POS {print \$2}" $CASE.outputeos)
	local B0=$(awk "FNR == $VOL0_POS {print \$3}" $CASE.outputeos)
	local BP=$(awk "FNR == $VOL0_POS {print \$4}" $CASE.outputeos)
    fi
    
    local VOL1=$(calc_vol ${CASE}_vol____0.00)
    #echo 'vol1: '$VOL1
    #echo 'vol0: '$VOL0
    #echo 'b: '$B0
    #echo 'bp: '$BP
    local ETA=$(bc -l <<< "scale=10; e( 1/3 * l($VOL0 / $VOL1) )" ) #"
    #echo 'eta: '$ETA
    local PRESSURE=$(bc -l <<< "scale=5; 3/2 * $B0 * ( $ETA^7 - $ETA^5 ) * (1 + 3/4 * ( $BP - 4 ) * ( $ETA^2 - 1 ) )") #"
    echo "$PRESSURE"
}

function test_pressure {
    local PRESSURE=$(check_pressure_zero | tail -n 1)
    local TEST=$(bc <<< "define check(input){if (input < 0.01 && input > -0.01) return 0; return 1;}; check($PRESSURE)") #"
    echo $TEST
}

function test_error {
    local ERROR_LIST=$(find -maxdepth 1 -type f -name "*.error" -printf "%s\n")
    local TEST=0
    for FILE in $ERROR_LIST
    do
	if [ $FILE -gt 0 ]
	then
	    local TEST=1
	fi
    done
    echo $TEST
}

function correct_vol {
    local CASE=$(wread_case)
    
    if [ -e $CASE.outputeos ]
    then
	printf 'First lines from .outputeos file:\n'
	head -n 31 $CASE.outputeos
	echo '.outputeos file end.'
	local BM_POS=$(grep -n 'Equation of state: Birch-Murnaghan' $CASE.outputeos | awk -F ':' '{print $1}')
	local VOL0_POS=$((BM_POS+4))
	local VOL0=$(awk "FNR == $VOL0_POS {print \$2}" $CASE.outputeos)
    elif [ -e ${CASE}_vol____0.00.scf ]
    then
	# create new .vol file for x eosfit
	echo 'No .outputeos file, running x eosfit...'
	if [ -e $CASE.vol ]
	then
	    rm $CASE.vol
	fi
	for SCF_FILE in `ls *_vol_*.scf`
	do
	    local ENE_part=`grepline :ENE $SCF_FILE 1 | tail -n +2 | awk '{print $NF}'`
	    local VOL_part=`grepline :VOL $SCF_FILE 1 | tail -n +2 | awk '{print $NF}'`
	    echo "  $VOL_part   $ENE_part" >> $CASE.vol
	done
	printf 'Y\n0\n' | x eosfit 
	printf 'First lines from .outputeos file:\n'
	head -n 31 $CASE.outputeos
	echo '.outputeos file end.'
	local BM_POS=$(grep -n 'Equation of state: Birch-Murnaghan' $CASE.outputeos | awk -F ':' '{print $1}')
	local VOL0_POS=$((BM_POS+4))
	local VOL0=$(awk "FNR == $VOL0_POS {print \$2}" $CASE.outputeos)
    else
	echo 'Reading from last step directory...'
	local KPT=$(wread_kpt $CASE)
        local RKM=$(wread_rkm $CASE)
        local XC=$(wread_xc $CASE)
        local LAST_STEP=$(wread_last_step)
        local LAST_NAME="rkm"$RKM"_"$KPT"k_"$XC"_"$LAST_STEP"_"
        
        printf 'First lines from .outputeos file:\n'
	head -n 31 $CASE.outputeos
	echo '.outputeos file end.'
	local BM_POS=$(grep -n 'Equation of state: Birch-Murnaghan' $LAST_NAME*/$CASE.outputeos | awk -F ':' '{print $1}')
	local VOL0_POS=$((BM_POS+4))
	local VOL0=$(awk "FNR == $VOL0_POS {print \$2}" $CASE.outputeos)
    fi
    
    local BRAVAIS=$(awk 'FNR == 2 {print $1}' $CASE.struct)
    case $BRAVAIS in
	P)  ;;
	F) local VOL0=$(bc <<< "scale=5; $VOL0 * 4") ;;
	B) local VOL0=$(bc <<< "scale=5; $VOL0 * 2") ;;
	CYZ) local VOL0=$(bc <<< "scale=5; $VOL0 * 2") ;;
	CXZ) local VOL0=$(bc <<< "scale=5; $VOL0 * 2") ;;
	CXY) local VOL0=$(bc <<< "scale=5; $VOL0 * 2") ;;
	R) local VOL0=$(bc <<< "scale=5; $VOL0 * 3") ;;
	#H) local VOL0=$(bc <<< "scale=5; $VOL0 * XXX") ;; --> to check
    esac
        
    local PARAM_A=$(awk 'FNR == 4 {print $1}' $CASE.struct)
    local PARAM_B=$(awk 'FNR == 4 {print $2}' $CASE.struct)
    local PARAM_C=$(awk 'FNR == 4 {print $3}' $CASE.struct)
    
    local VOL1=$(calc_vol $CASE)
    local PARAM_K=$(bc -l <<< "scale=10; e( (1/3) * l($VOL0/$VOL1) )" ) #"
    
    local NEW_PARAM_A=$(bc <<< "scale=6; $PARAM_A * $PARAM_K")
    local NEW_PARAM_B=$(bc <<< "scale=6; $PARAM_B * $PARAM_K")
    local NEW_PARAM_C=$(bc <<< "scale=6; $PARAM_C * $PARAM_K")
    
    local NEW_PARAM_A=$(printf "%.6f" $NEW_PARAM_A)
    local NEW_PARAM_B=$(printf "%.6f" $NEW_PARAM_B)
    local NEW_PARAM_C=$(printf "%.6f" $NEW_PARAM_C)
    
    echo "Vol0: $VOL0, Vol1: $VOL1"
    echo 'k-scaling parameter: '$PARAM_K
    echo 'a: '$PARAM_A' ---> '$NEW_PARAM_A
    echo 'b: '$PARAM_B' ---> '$NEW_PARAM_B
    echo 'c: '$PARAM_C' ---> '$NEW_PARAM_C
    
    sed -i "s/$PARAM_A/$NEW_PARAM_A/" $CASE.struct
    sed -i "s/$PARAM_B/$NEW_PARAM_B/" $CASE.struct
    sed -i "s/$PARAM_C/$NEW_PARAM_C/" $CASE.struct
    
    echo "$CASE.struct file has been updated."
    
}

function prep_job {

    if [ -f .job_config ]
    then
	rm .job_config
    fi 

    echo "Preparing new .job_config file..."
    
    local CASE=$(wread_case)
    local K_POINTS_NO=$(grep -n END $CASE.klist | awk -F ':' '{print $1}')
    local K_POINTS_NO=$(($K_POINTS_NO-1))
    local MAX_CORES=24
    local NUM_CORES=1
    
    echo "Number of k-points from .klist: $K_POINTS_NO"
    echo "Maximum number of cores: $MAX_CORES"
    for N in `seq $MAX_CORES`
    do
	local MOD=$(($K_POINTS_NO%$N))
	if [ $MOD -eq 0 ]
	then
	    local NUM_CORES=$N
	fi
    done
    echo "Optimum number of cores is then: $NUM_CORES"
    
    # Defaults
    local WALLTIME=1:00:00
    local MPI_DIV=1
    
    local OPTIND
    while getopts ":t:f:" OPT
    do
	case $OPT in
	    t)
		echo "Setting walltime to $OPTARG"
		local WALLTIME=$OPTARG
		;;
	    f)
		echo "Forced maximum number of cores with MPI: $OPTARG"
		if [ $OPTARG -le $MAX_CORES ]
		then
		    local MPI_DIV=$(($OPTARG/$NUM_CORES))
		    if [ $MPI_DIV -gt 8 ]
		    then
			local MPI_DIV=8
			echo "Limit MPI to 8!"
		    fi
		    local NUM_CORES=$(($NUM_CORES*$MPI_DIV))
		else
		    echo "Forced number greater than MAX_CORES, back to default"
		fi
		echo "Setting number of cores: $NUM_CORES with MPI: $MPI_DIV"
		;;
	    \?)
		echo "Invalid option: -$OPTARG"
		exit 1
		;;
	    :)
		echo "Option -$OPTARG requires an argument."
		exit 1
		;;
	esac
    done
    shift $((OPTIND-1))

    cat <<__EOF__ > .job_config
# your e-mail address
email=$USER_EMAIL_ADDRESS

# Name of the queue for the job (leave default)
SQueue=plgrid

# Grant for calculations (leave default)
grantID=$CURRENT_GRANT_ID

# Job name (name of a directory is default)
SJobName=`pwd | awk -F '/' '{print $NF}'`

# Walltime
WALLTIME=$WALLTIME

# Number of cores for calculations
NCPUS=$NUM_CORES

# Parameters for parallelization methods
# --> \$JOB_OMP * \$MPI_DIV should divide \$NCPUS for best efficiency!
# --> in general, best to leave 1 and 1
JOB_OMP=1
MPI_DIV=$MPI_DIV
__EOF__



    echo '.job_config file has been created. Please, ensure you use your e-mail adress.'
    
}

function prep_job_nohere {

    if [ -f .job_config ]
    then
	rm .job_config
    fi 

    echo "Preparing new .job_config file..."
    
    local CASE=$(wread_case)
    local K_POINTS_NO=$(grep -n END $CASE.klist | awk -F ':' '{print $1}')
    local K_POINTS_NO=$(($K_POINTS_NO-1))
    local MAX_CORES=24
    local NUM_CORES=1
    
    echo "Number of k-points from .klist: $K_POINTS_NO"
    echo "Maximum number of cores: $MAX_CORES"
    for N in `seq $MAX_CORES`
    do
	local MOD=$(($K_POINTS_NO%$N))
	if [ $MOD -eq 0 ]
	then
	    local NUM_CORES=$N
	fi
    done
    echo "Optimum number of cores is then: $NUM_CORES"
    
    # Defaults
    WALLTIME=1:00:00
    
    local OPTIND
    while getopts ":t:" OPT
    do
	case $OPT in
	    t)
		echo "Setting walltime to $OPTARG"
		WALLTIME=$OPTARG
		;;
	    \?)
		echo "Invalid option: -$OPTARG"
		exit 1
		;;
	    :)
		echo "Option -$OPTARG requires an argument."
		exit 1
		;;
	esac
    done
    shift $((OPTIND-1))


    echo "# your e-mail address
email=$USER_EMAIL_ADDRESS

# Name of the queue for the job (leave default)
SQueue=plgrid

# Grant for calculations (leave default)
grantID=$CURRENT_GRANT_ID

# Job name (name of a directory is default)
SJobName=$CASE

# Walltime
WALLTIME=$WALLTIME

# Number of cores for calculations
NCPUS=$NUM_CORES

# Parameters for parallelization methods
# --> "'$JOB_OMP * $MPI_DIV should divide $NCPUS'" for best efficiency!
# --> in general, best to leave 1 and 1
JOB_OMP=1
MPI_DIV=1
" >> .job.config


    echo '.job_config file has been created. Please, ensure you use your e-mail adress.'
    
}

function run_job {
    INPUT=$@
    $HOME/wop/w2k_18.2_mpi_nohere "$INPUT"
}

function run_mini {
    INPUT='run_lapw -p -min -ec 0.0001 -fc 1.0'
    $HOME/wop/w2k_18.2_mpi_nohere "$INPUT"
}

function run_opt {
    INPUT='./optimize.job'
    $HOME/wop/w2k_18.2_mpi_nohere "$INPUT"
}

function step_opt {
    echo "Running STEP: optimization via EOS..."
    
    save_next scf
    prep_opt
    retrieve_zero
    echo "Case: "$(wread_case)
    run_opt
}

function step_opt_analysis {
    echo "Running STEP: optimization analysis..."
    
    restore_zero
    correct_vol
}

function step_pos {
    echo "Running STEP: optimization of atomic positions..."

    save_next eos
    echo "Case: "$(wread_case)
    run_mini
}

function step_first {
    echo "Running STEP: first..."
    
    echo "Case: "$(wread_case)
    run_job run_lapw -p -ec 0.0001 -cc 0.01
}

function step_last {
    echo "Running STEP: last..."
    
    echo "Case: "$(wread_case)
    save_next eos
    run_job run_lapw -p -min -ec 0.00001 -fc 0.1 -cc 0.0001
}

function chk_std {
    tail -n 10 STDOUT
}

function sleep_till_end {
    while [ -e .slurm_run ]
    do
	sleep 20
    done
    echo "SLURM job has ended."
}

function run_optimizer {
    touch .optimizer
    if [ -e STDOUT_optimizer ]
    then
	rm STDOUT_optimizer
    fi
    echo "STEP first" >> .optimizer_history
    step_first | tee STDOUT_optimizer
    sleep_till_end
    ETEST=$(test_error)
    PTEST=1
    
    if [ $ETEST -ne 0 ] #&& [ $? -eq 0 ]
    then
	echo "Error after first SCF."
	rm .optimizer
	return 1
    fi
    
    while [ $PTEST -eq 1 ] && [ -e .optimizer ]
    do
	echo "STEP opt" >> .optimizer_history
	step_opt | tee -a STDOUT_optimizer
	sleep_till_end
	ETEST=$(test_error)
	
	if [ $ETEST -eq 0 ] #&& [ $? -eq 0 ]
	then
	    PTEST=$(test_pressure)
	    if [ $PTEST -eq 1 ]
	    then
		step_opt_analysis | tee -a STDOUT_optimizer
		echo "STEP pos" >> .optimizer_history
		step_pos | tee -a STDOUT_optimizer
		sleep_till_end
		ETEST=$(test_error)
		
		if [ $ETEST -ne 0 ] #&& [ $? -eq 0 ]
		then
		    echo "Error after MSR run."
		    rm .optimizer
		    return 1
		fi
	    fi
	else
	    echo "Error after EOS run."
	    rm .optimizer
	    return 1
	fi
    done
    
    if [ $PTEST -eq 0 ]
    then
	step_opt_analysis | tee -a STDOUT_optimizer
	echo "STEP last" >> .optimizer_history
	step_last | tee -a STDOUT_optimizer
	sleep_till_end
	ETEST=$(test_error)
	
	if [ $ETEST -ne 0 ] #&& [ $? -eq 0 ]
	then
	    echo "Error after last SCF run."
	    rm .optimizer
	    return 1
	fi
    fi
    
    if [ -e .optimizer ]
    then
	rm .optimizer
    fi
}
