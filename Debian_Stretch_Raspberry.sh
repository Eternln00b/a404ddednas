#!/bin/bash

############################################
## Author : https://github.com/Eternln00b ##
##########################################################################################
## based on this script https://gist.github.com/stewdk/f4f36c3f6599072583bd40f15b5cdbef ##
##########################################################################################

source config_variables

finish () {
	sync
	local MNTPNTS=("${MNTROOTFS}proc" "${MNTROOTFS}dev/pts" "${MNTROOTFS}dev" "${MNTROOTFS}sys" "${MNTROOTFS}tmp" "${MNTBOOT}" "${MNTROOTFS}")
	for MNTPNT in "${MNTPNTS[@]}"
	do
		umount -l "${MNTPNT}" || true
	done	
	kpartx -dvs ${IMGFILE} >/dev/null 2>&1
	mv ${IMGFILE} ${OUTPUT_IMG_DIR}
	umount -l ${MNTRAMDISK} || true
	rm -rf ${MNTROOTFS} || true
	rmdir ${MNTRAMDISK} || true
	if [[ ${IMG_COMPRESSION} ]];then

		echo -en "img compression !\n\n"
		xz -k --best ${OUTPUT_IMG_DIR}/${IMGNAME}.img

	fi
	chown -R $(id -nu 1000):$(id -nu 1000) ${OUTPUT_IMG_DIR}
}

packages() {

	local softwares=("g++-arm-linux-gnueabi" "gcc-aarch64-linux-gnu" "g++-aarch64-linux-gnu" "gcc-arm-linux-gnueabihf" "g++-arm-linux-gnueabihf" "gcc-arm-linux-gnueabi" "pkg-config-aarch64-linux-gnu" "pkg-config-arm-linux-gnueabihf"  
	"pkg-config-arm-linux-gnueabi" "bison" "flex" "debootstrap" "qemu-utils" "kpartx" "qemu-user-static" "binfmt-support" "parted" "bc" "libncurses5-dev" "libssl-dev" "device-tree-compiler" "squashfs-tools" "wpasupplicant"
	"git" "wget" "parallel")

	for checking_softwares in "${softwares[@]}"
	do

		if [[ $(dpkg-query --show --showformat='${db:Status-Status}\n' ''$checking_softwares'') == "not-installed" ]];then 
	 
    		echo "The package $checking_softwares is being installed ..."
			apt install -y -qq -o=Dpkg::Use-Pty=0 $checking_softwares >/dev/null 2>&1

		fi

	done

}

Which_Raspberry_pi() {

	local LIGNE1="===================================================="
	local MESSAGE1=""
	MESSAGE1="\nwhich Raspberry Pi and which kernel please ?\n\n${LIGNE1}\n
	Raspberry Pi 4 in 64bits: Debian_RPI.sh -4 64bits\nRaspberry Pi 4 in 32bits: Debian_RPI.sh -4 32bits\n\n${LIGNE1}\n
	Raspberry Pi 3 in 64bits: Debian_RPI.sh -3 64bits\nRaspberry Pi 3 in 32bits: Debian_RPI.sh -3 32bits\n\n${LIGNE1}\n
	Raspberry Pi 2 in 32bits: Debian_RPI.sh -2\n\n${LIGNE1}\n\nRaspberry Pi 0,1 in 32bits: Debian_RPI.sh -1\n\n${LIGNE1}
	\nkernel configuration : Debian_RPI.sh -4 64bits -c\n\n"
	
	local MESSAGE2="\nWhich kernel please ? 64bits or 32bits ?\n\n"
	local MESSAGE3="\nThe first argument do not require an argument\n\n"
	
	[[ $1 == "MESSAGE1" ]] && local MESSAGE=$MESSAGE1
	[[ $1 == "MESSAGE2" ]] && local MESSAGE=$MESSAGE2
	[[ $1 == "MESSAGE3" ]] && local MESSAGE=$MESSAGE3
	
	echo -en "$MESSAGE" | tr -d "\t"

}

Options_processing() {

	while getopts ":4:3:21cx" options ; do
	case $options in

		4)

			if [[ $OPTARG == "64bits" || $OPTARG == "32bits" ]];then

				[[  $OPTARG == "64bits" ]] && KERNEL="kernel8" 
				[[  $OPTARG == "32bits" ]] && KERNEL="kernel7l" 
				OS=${OPTARG}
				pi="4"

			fi		
			;;

		3)

			if [[ $OPTARG == "64bits" || $OPTARG == "32bits" ]];then

				[[  $OPTARG == "64bits" ]] && KERNEL="kernel8" 
				[[  $OPTARG == "32bits" ]] && KERNEL="kernel7" 
				OS=${OPTARG}
				pi="3"

			fi	
			;;

		2)

			KERNEL="kernel7"
			pi="2"
			;;

		1)

			KERNEL="kernel"	
			pi="1"
			;;	

		c)

			KERNEL_CONFIGURE=true
			;;
		
		x)

			IMG_COMPRESSION=true
			;;
		
		:)

			Which_Raspberry_pi "MESSAGE2"
			exit 1
			;;


		\?)

			Which_Raspberry_pi "MESSAGE1" 
			exit 1
			;;

		*)

			Which_Raspberry_pi "MESSAGE1" 
			exit 1
			;;

	esac
	done

	if [[ ! -d ${TMP_DIR} ]];then 

		mkdir -p ${TMP_DIR}

	else 

		rm -rf ${TMP_DIR}/*

	fi 

	[[ -d ${OUTPUT_IMG_DIR} ]] && rm -rf ${OUTPUT_IMG_DIR}
	[[ ! -f ${TMP_DIR}/exported-variables ]] && touch ${TMP_DIR}/exported-variables
	[[ ! -d ${OUTPUT_IMG_DIR} ]] && mkdir -p ${OUTPUT_IMG_DIR}
	[[ ! -d ${WRKDIR} ]] && mkdir -p ${WRKDIR}

	if [[ ${pi} == "4" || ${pi} == "3" ]];then

		echo "${pi}:${OS}:${KERNEL}" >> ${TMP_DIR}/config.kernel.tmp

	else

		echo "${pi}:${KERNEL}" >> ${TMP_DIR}/config.kernel.tmp

	fi
	
}

set_compiler() {

	if [[ $1 == "kernel8" ]];then

		DARCH="arm64"
		KARCH="arm64"
		QARCH="aarch64"
		CROSS_COMPILER=aarch64-linux-gnu-
		KERNEL_IMG="Image"
		[[ $pi == "3" ]] && RPI_DEFCONFIG="bcmrpi3_defconfig"
		[[ $pi == "4" ]] && RPI_DEFCONFIG="bcm2711_defconfig"
		echo -en "\nCompiling Debian for the Raspberry Pi ${pi} in 64 bits\n\n"

	else

		DARCH="armhf"
		KARCH="arm"
		QARCH="arm"
		CROSS_COMPILER=arm-linux-gnueabihf-
		KERNEL_IMG="zImage"
		[[ $1 == "kernel" ]] && RPI_DEFCONFIG="bcmrpi_defconfig"
		[[ $1 == "kernel7" ]] && RPI_DEFCONFIG="bcm2709_defconfig"
		[[ $1 == "kernel7l" ]] && RPI_DEFCONFIG="bcm2711_defconfig"
		echo -en "\nCompiling Debian for the Raspberry Pi ${pi} in 32 bits\n\n"

	fi

	if [[ $pi == "1" ]]; then

		IMGNAME=Debian_Stretch_${QARCH}_rpi0_1		

	else

		IMGNAME=Debian_Stretch_${QARCH}_rpi${pi}

	fi 

	IMGFILE=${MNTRAMDISK}${IMGNAME}.img

}

check_if_downloaded(){

	local project=$1
	local folder=$2

	if [[ -d ${folder} ]];then 

		echo "the sources files \"${project//.git}\" are here !"

	else

		[[ ! -f ${TMP_DIR}/github ]] && touch ${TMP_DIR}/github
		echo "${project}" >> ${TMP_DIR}/github

	fi
	
}

download_source() {

	source /tmp/Debian_Rpi/exported-variables

	local github_download=$1
	local gitlink="https://github.com/"
	local folder_source=${WRKDIR}${github_download//.git} 

	[[ "${github_download}" == "RPi-Distro/firmware-nonfree.git" ]] && position=-150 && branch=buster
	[[ "${github_download}" == "raspberrypi/linux.git" ]] && position=+100
	[[ "${github_download}" == "raspberrypi/firmware.git" ]] && position=80

	if [[ "${kernel}" == "kernel8" && "${github_download}" == "raspberrypi/linux.git" ]];then

		xterm -geometry ${position} -e "git clone --branch rpi-5.15.y --single-branch ${gitlink}${github_download} ${folder_source}"
	
	elif [[ -n ${branch} ]];then

		xterm -geometry ${position} -e "git clone --branch ${branch} --single-branch ${gitlink}${github_download} ${folder_source}"

	else

		xterm -geometry ${position} -e "git clone --single-branch ${gitlink}${github_download} ${folder_source}"

	fi

	chown -R $(id -nu 1000):$(id -nu 1000) ${folder_source}
	chmod 0755 ${folder_source}

}

pre_kernel_compile() {

	source ${TMP_DIR}/exported-variables

	local kernel_config=${WRKDIR}raspberrypi/linux/config.kernel
	local kernel_config_tmp=${TMP_DIR}/config.kernel.tmp
	local kernel_rpi=${WRKDIR}raspberrypi/linux/arch/${KARCH}/boot/${KERNEL_IMG}

	if [[ ! -f ${kernel_config} ]];then 

		mv ${kernel_config_tmp}	${kernel_config}

	else

		if [[ $(diff -s ${kernel_config_tmp} ${kernel_config} > /dev/null ; echo $?) -eq 1 || ${KERNEL_CONFIGURE} ]];then

			[[ -f ${kernel_rpi} ]] && rm -rf ${kernel_rpi}
			rm -rf ${kernel_config}
			cd ${WRKDIR}raspberrypi/linux
			make -j${JOBS} mrproper &> /dev/null
	    		make -j${JOBS} distclean &> /dev/null
			make -j${JOBS} clean &> /dev/null
			mv ${kernel_config_tmp}	${kernel_config}

		fi

	fi
    
}

kernel_compile() {

	source ${TMP_DIR}/exported-variables
	echo -en "Building kernel. This takes a while ... \n\n"
	cd ${WRKDIR}raspberrypi/linux
	make ARCH=${KARCH} CROSS_COMPILE=${CROSS_COMPILER} ${RPI_DEFCONFIG} -j${JOBS} &> /dev/null
	[[ ${KERNEL_CONFIGURE} ]] && xterm -geometry 210x200+100-10 -e 'make ARCH='${KARCH}' CROSS_COMPILE='${CROSS_COMPILER}' -j'${JOBS}' menuconfig '
	xterm -geometry 80 -e 'make ARCH='${KARCH}' CROSS_COMPILE='${CROSS_COMPILER}' '${KERNEL_IMG}' modules dtbs -j'${JOBS}''
	
}

Debian_build() {

	local TMP_DIR=/tmp/Debian_Rpi
	local MOUNTS_DIRS=("proc" "dev" "/dev/pts" "sys" "tmp")
	local BOOT_PART_SIZE=$1
	local IMG_SIZE=$2

	echo -en "Building the Debian image ! \n\n"

	mkdir -p ${MNTRAMDISK} ${MNTROOTFS} 
	mount -t tmpfs -o size=2g tmpfs ${MNTRAMDISK}

	qemu-img create -f raw ${IMGFILE} ${IMG_SIZE} > /dev/null 
	(echo "n"; echo "p"; echo "1"; echo "2048"; echo "+${BOOT_PART_SIZE}"; echo "n"; echo "p"; echo "2"; echo ""; echo ""; 
 	 echo "t"; echo "1"; echo "c"; echo "w") | fdisk ${IMGFILE} > /dev/null

	LOOPDEVS=$(kpartx -avs ${IMGFILE} | awk '{print $3}')
	LOOPDEVBOOT=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $1}')
	LOOPDEVROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $2}')

	mkfs.vfat ${LOOPDEVBOOT} >/dev/null 2>&1
	mkfs.ext4 ${LOOPDEVROOTFS} >/dev/null 2>&1

	fatlabel ${LOOPDEVBOOT} Boot >/dev/null 2>&1
	e2label ${LOOPDEVROOTFS} Debian >/dev/null 2>&1

	mount ${LOOPDEVROOTFS} ${MNTROOTFS}
	xterm -T "build debian" -geometry 215-100+5 -e 'qemu-debootstrap --keyring '${Keyring}' --include=ca-certificates --arch='${DARCH}' stretch '${MNTROOTFS}' '${Apt_source}''
	mount ${LOOPDEVBOOT} ${MNTBOOT}
	
	for mount_dir in "${MOUNTS_DIRS[@]}"
	do

		mount -o bind /${mount_dir} ${MNTROOTFS}${mount_dir}

	done
	
	cp $( which qemu-${QARCH}-static ) ${MNTROOTFS}usr/bin/
	cp ${WRKDIR}raspberrypi/firmware/boot/bootcode.bin ${WRKDIR}raspberrypi/firmware/boot/fixup*.dat ${WRKDIR}raspberrypi/firmware/boot/start*.elf ${MNTBOOT}
	sed -e "s|KERNEL=|KERNEL=${KERNEL}|" -i ${TMP_DIR}/chroot_scripts/package_debian
	xterm -geometry 190x180+90-20 -e 'chroot '${MNTROOTFS}' '${TMP_DIR}'/chroot_scripts/package_debian'
	chroot ${MNTROOTFS} ${TMP_DIR}/externals/post_install_scripts
	# xterm -geometry 210x200+100-10 -e 'chroot '${MNTROOTFS}' /bin/bash'

}

######################
## script checkings ##
######################

if [[ $(id -u) -ne 0 || $( wget -q -o /dev/null --spider https://www.google.com; echo $? ) -ne 0 || $( id -nu 1000 > /dev/null; echo $?) -ne 0 ]]; then

	echo "[!] This script must run as root or you are not connected to internet or you do not have an user with the id 1000"
	exit 1

fi

if [[ $(lsb_release -i | grep -o "Ubuntu") != "Ubuntu" ]];then

	echo "[!] This script was made only for Ubuntu"
	exit 1

else

	if [[ -z $( which dpkg-query ) || -z $( which apt ) ]];then
	
		echo "[!] dpkg-query or apt are there ?"
		exit 1

	fi

fi

if [[ "$#" -eq 0 ]];then
	
	Which_Raspberry_pi "MESSAGE1"
	exit 1 

elif [[  $3 == "-c" ]];then

	[[ $1 == "-1" || $1 == "-2" ]] && { 
		
		Which_Raspberry_pi "MESSAGE3"
		exit 1 

	}
	
fi

######################
## script beginning ##
######################

Options_processing "$@"
packages
set_compiler "$KERNEL"

rpi_source=("RPi-Distro/firmware-nonfree.git" "raspberrypi/linux.git" "raspberrypi/firmware.git")

for sources in "${rpi_source[@]}"
do

	check_if_downloaded ${sources} ${WRKDIR}${sources//.git} 

done

echo

/bin/cat /dev/null >> ${TMP_DIR}/exported-variables
/bin/cat <<exported_variables >> ${TMP_DIR}/exported-variables
Apt_source=${Apt_source}
CROSS_COMPILER=${CROSS_COMPILER}
DARCH=${DARCH}
HOSTNAME_RPI=${HOSTNAME_RPI}
IMGFILE=${IMGFILE}
KARCH=${KARCH}
KERNEL_IMG=${KERNEL_IMG}
KERNEL=${KERNEL}
Keyring=${Keyring}
MNTBOOT=${MNTBOOT}
MNTRAMDISK=${MNTRAMDISK}
MNTROOTFS=${MNTROOTFS}
QARCH=${QARCH}
RPI_DEFCONFIG=${RPI_DEFCONFIG}
PASSWORD=${PASSWORD}
RPIUSER=${RPIUSER}
SMBUSER=${SMBUSER}
WRKDIR=${WRKDIR}
Threads=$(lscpu | grep -oP '(Thread)'.* | awk '{print $4}')
Procs=$(nproc)
JOBS=$(echo $(($Threads*$Procs)))
exported_variables

[[ -n ${KERNEL_CONFIGURE} ]] && echo "KERNEL_CONFIGURE=${KERNEL_CONFIGURE}" >> ${TMP_DIR}/exported

if [[ -f ${TMP_DIR}/github ]];then

	githubs_download=$(cat ${TMP_DIR}/github | wc -l)

	if [[ githubs_download -gt 1 && githubs_download -le 3 ]];then

		echo "Downloading the sources codes"
		export -f download_source
		/bin/bash -c "/usr/bin/parallel -j${JOBS} download_source < ${TMP_DIR}/github" >/dev/null 2>&1

	else

		if [[ githubs_download -eq 1  ]];then 

			download_source $(cat ${TMP_DIR}/github)

		else 
		
			if [[ githubs_download -gt 3 || githubs_download -lt 1 ]];then

				echo " ... it's weird"
				exit 1

			fi
		
		fi

	fi

fi

if [[ -n $KERNEL ]];then

	trap finish EXIT

	cp -r $(pwd)/chroot_scripts ${TMP_DIR}
	cp -r $(pwd)/externals ${TMP_DIR}
	sed -e '4i\RPIUSER='"$RPIUSER"'\nHOSTNAME_RPI='"$HOSTNAME_RPI"'' -i ${TMP_DIR}/chroot_scripts/package_debian
	chmod +x ${TMP_DIR}/chroot_scripts/package_debian ${TMP_DIR}/externals/post_install_scripts

 	Debian_build 260M 1250M

	echo "Compressing firmware"
	mksquashfs ${WRKDIR}RPi-Distro/firmware-nonfree ${MNTBOOT}firmware.sqfs -b 1048576 -comp xz -Xdict-size 100% >/dev/null 2>&1

	pre_kernel_compile
	[[ ! -f ${WRKDIR}raspberrypi/linux/arch/${KARCH}/boot/${KERNEL_IMG} ]] && kernel_compile 

	echo -en "\nInstalling the kernel ...\n\n"
	cp ${WRKDIR}raspberrypi/linux/arch/${KARCH}/boot/${KERNEL_IMG} ${MNTBOOT}${KERNEL}.img
    	[[ ${KARCH} == "arm" ]] && cp ${WRKDIR}raspberrypi/linux/arch/${KARCH}/boot/dts/*.dtb ${MNTBOOT}
	[[ ${KARCH} == "arm64" ]] && cp ${WRKDIR}raspberrypi/linux/arch/${KARCH}/boot/dts/broadcom/*.dtb ${MNTBOOT}
    	cd ${WRKDIR}raspberrypi/linux
    	make ARCH=${KARCH} CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=${MNTROOTFS} modules_install -j ${JOBS} &> /dev/null

else

	Which_Raspberry_pi "MESSAGE2"
	exit 1

fi
