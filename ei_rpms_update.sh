#!/bin/bash

## IMP CSR procedure: Automate download, sync and update rpms in all plex
## 1st version: Created by ChrisZ at 20191207
## 2nd version: Add automate download from ftp3
## 3rd version: Optimized Download

## Usage: Input all the entire rpm name which are shown in service-now into /tmp/servicenow.list.

SN="/tmp/servicenow.list"
DL="/tmp/download.list"
RPM_PATH="/tmp/rpms"
update_repo="2020-02"

URL6="https://ftp3.linux.ibm.com/dl.php?file=/redhat/yum/server/6/6Server/x86_64/os/Packages"
URL7="https://ftp3.linux.ibm.com/dl.php?file=/redhat/yum/server/7/7Server/x86_64/os/Packages"
SLES_X86_URL="https://ftp3.linux.ibm.com/dl.php?file=/suse/catalogs/SLES11-SP4-LTSS-Updates/sle-11-x86_64/rpm/x86_64"
SLES_PPC64_URL="https://ftp3.linux.ibm.com/dl.php?file=/suse/catalogs/SLES11-SP4-LTSS-Updates/sle-11-ppc64/rpm/ppc64"

REPOSYNC_LIST="lssys -qe role==ROLE-EI-DEFAULT-REPOSYNC"
REPOMG_LIST="lssys -qe role==role-ei-default-repoManage*"
SLES_X86_LIST="lssys -qe oslevel==*sles*x86* nodestatus!=BAD"
SLES_PPC64_LIST="lssys -qe oslevel==*sles*ppc64* nodestatus!=BAD"
RH6_LIST="lssys -qe oslevel==*rh6* nodestatus!=BAD"
RH7_LIST="lssys -qe oslevel==*rh7* nodestatus!=BAD"

RH6_REPO="/fs/system/images/redhat/62/latest/rhel-6-server-rpms/Packages/"
RH7_REPO="/fs/system/images/redhat/72/latest/rhel-7-server-rpms/Packages/"
RH7_S_REPO="/repo/os/rhel/7/x86_64/updates/${update_repo}/"

[[ ! -e ${SN} ]] && echo "${SN} do NOT exsit!" && exit
[[ $UID -ne 0 ]] && echo "Should run as root" && exit
mkdir -p ${RPM_PATH}/{redhat6,redhat7,sles/{x86_64,ppc64}} &> /dev/null

read -p "Please input your ftp3 account: " EMAIL
read -p "Please input your ftp3 password: " -s PW

## Find the actually required packages list
cat /dev/null > ${DL}
case $(hostname) in
    z10000)
  SITE="z1"
  REPOSYNC_LIST2=$($REPOSYNC_LIST |grep ^z)
 	PLEX="z1"
  ;;
    v10000)
  SITE="p1"
	REPOSYNC_LIST2=$($REPOSYNC_LIST |grep ^[vw]1)
	PLEX="[vwp]1|s"
  ;;
    v30000)
  SITE="p3"
	REPOSYNC_LIST2=$($REPOSYNC_LIST |grep ^[vw]3)
	PLEX="[vwp]3"
  ;;
    v50000)
  SITE="p5"
	REPOSYNC_LIST2=$($REPOSYNC_LIST |grep ^[vw]5)
	PLEX="[vwp]5"
  ;;
      *) 
  echo "Please run $0 on CWS node" && exit
  ;;
esac

echo -e "\nScanning and matching..."
for K in $(cat ${SN} |grep -v ^# |grep -v ^$ |sed 's/\t//g' |sed 's/ //g'|uniq)
do
	Q=$(echo ${K} |sed "s/\(.*\)-.*/\1/g"  |sed 's/\(.*\)-.*/\1/g')

	echo ${K} |egrep el6 &> /dev/null && OS="*rh6*"
	echo ${K} |egrep el7 &> /dev/null && OS="*rh7*"
	echo ${K} |egrep -v "el6|el7" |grep x86_64 &> /dev/null && OS="*sles*x86_64*"
	echo ${K} |egrep -v "el6|el7" |grep ppc64 &> /dev/null && OS="*sles*ppc64*"
	echo ${K} |egrep -v "el6|el7" |grep noarch &> /dev/null && OS="*sles*"	

	if echo ${K} |grep ".el[7|6]" |grep x86_64 &> /dev/null;then

		COUNT=0;TMP_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD realm==*.${SITE} |xargs -n50 |tr " " ",");do echo $I;TMP_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9].*x86_64"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let COUNT+=${TMP_COUNT};done

		if [[ $COUNT -eq 0 && ${SITE} == "p1" && ${OS} == "*rh7*" ]];then
			S_COUNT=0;TMP_S_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD eihostname==softlayer |xargs -n50 |tr " " ",");do echo $I;TMP_S_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9].*x86_64"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let S_COUNT+=${TMP_S_COUNT};done
		fi

	elif echo ${K} |grep ".el[7|6]" |grep i686 &> /dev/null;then

		COUNT=0;TMP_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD realm==*.${SITE} |xargs -n50 |tr " " ",");do echo $I;TMP_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9].*i686"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let COUNT+=${TMP_COUNT};done

		if [[ $COUNT -eq 0 && ${SITE} == "p1" && ${OS} == "*rh7*" ]];then
			S_COUNT=0;TMP_S_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD eihostname==softlayer |xargs -n50 |tr " " ",");do echo $I;TMP_S_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9].*i686"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let S_COUNT+=${TMP_S_COUNT};done
		fi

	elif echo ${K} |grep ".el[7|6]" |grep noarch &> /dev/null;then
		
		COUNT=0;TMP_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD realm==*.${SITE} |xargs -n50 |tr " " ",");do echo $I;TMP_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9].*noarch"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let COUNT+=${TMP_COUNT};done

	else

		COUNT=0;TMP_COUNT=0;for I in $(lssys -qe oslevel==${OS} nodestatus!=BAD realm==*.${SITE} |xargs -n50 |tr " " ",");do echo $I;TMP_COUNT=$(dssh -kn ${I} 'rpm -qa |egrep "^'${Q}'-[0-9]"' |grep -v TodaroPromptBuster 2> /dev/null |wc -l);let COUNT+=${TMP_COUNT};done

	fi

	[[ ${COUNT} -gt 0 || ${S_COUNT} -gt 0 ]] && echo ${K} >> ${DL}
done

if [[ ! -s ${DL} ]];then
	echo -e "\033[34m \nNot suitable for ${SITE}.\n\033[0m"
	exit
fi

## Download the packages
DL_LIST=$(cat ${DL} |sort -n |uniq)
P_LIST=$(find ${RPM_PATH} -type f |awk -F"/" '{print $NF}' |sort -n |uniq)

if [[ ${DL_LIST} != ${P_LIST} ]];then
	find ${RPM_PATH} -type f -exec mv {} /tmp \;

	for I in $(cat ${DL} |grep el7 |grep -v noarch)
	do
		LABEL=${I:0:1}
		wget --user=${EMAIL} --password=${PW} --no-check-certificate ${URL7}/${LABEL}/${I} -O ${RPM_PATH}/redhat7/${I}
	done

	for I in $(cat ${DL} |grep el6 |grep -v noarch)
	do
		LABEL=${I:0:1}
		wget --user=${EMAIL} --password=${PW} --no-check-certificate ${URL6}/${LABEL}/${I} -O ${RPM_PATH}/redhat6/${I}
	done

	for I in $(cat ${DL} |egrep -v "el6|el7" |grep x86_64)
	do
		wget --user=${EMAIL} --password=${PW} --no-check-certificate ${SLES_X86_URL}/${I} -O ${RPM_PATH}/sles/x86_64/${I}
	done

	for I in $(cat ${DL} |egrep -v "el6|el7" |grep ppc64)
	do
		wget --user=${EMAIL} --password=${PW} --no-check-certificate ${SLES_PPC64_URL}/${I} -O ${RPM_PATH}/sles/ppc64/${I}
	done

	for I in $(cat ${DL} |grep noarch)
	do
		echo -e "\033[31m noarch packages can NOT download automatically at present,please download ${I} by manually,and put both in sles x86 and ppc64 path! \033[0m"
	done
fi

tsum=0
for I in $(find ${RPM_PATH} -type f)
do
	TYPE=$(file ${I} |awk -F":" '{print $2}' |sed 's/^ //g' |awk '{print $1}')
	if [[ ${TYPE} != "RPM" ]];then
		echo -e "\033[31m ${I##*/} is suitable for ${SITE},but can't download from ftp3,please download by manually!\n \033[0m"
		tsum+=1
		mv ${I} /tmp
	fi
done
if [[ ${tsum} -gt 0 ]];then
	exit 1
fi

DL_LIST=$(cat ${DL} |sort -n |uniq)
P_LIST=$(find ${RPM_PATH} -type f |awk -F"/" '{print $NF}' |sort -n |uniq)
if [[ ${DL_LIST} != ${P_LIST} ]];then
	echo -e "\033[31m The download rpms is not equal than actually required,please check first! \033[0m"
	exit 2
else
	for I in $(cat ${DL});do
  	echo -e "\033[34m \n${I} is suitable for ${SITE}.and prepared well in ${RPM_PATH} \033[0m"
	done
fi
echo

# softlayer rpms sync
if [[ $(hostname) == "v10000" ]];then
	if [[ $(ls ${RPM_PATH}/redhat7/*el7*.rpm 2> /dev/null |wc -l) -ne 0 ]];then
		SNODE=$(${REPOMG_LIST} |sort -n |tail -1)
		S_SUM=0
		for V in $(ls ${RPM_PATH}/redhat7/*el7*.rpm |awk -F"/" '{print $NF}')
		do
		 	ssh ${SNODE} "ls ${RH7_S_REPO} |grep ${V}"
			if [[ $? -ne 0 ]];then
				chown -R root:root ${RPM_PATH}
				chmod -R 0664 ${RPM_PATH}/redhat7
				scp -p ${RPM_PATH}/redhat7/${V} ${SNODE}:${RH7_S_REPO}
				let S_SUM+=1
			else
        			echo "${V} already on ${SNODE}"
			fi
		done				
		[[ ${S_SUM} -gt 0 ]] && echo "begin createrepo on ${SNODE}" && ssh ${SNODE} 'cd '${RH7_S_REPO}' && createrepo . && /usr/local/bin/repoSyncToIC $PWD'
	fi
fi

## rsync rpms to repo server
chown -R root:root ${RPM_PATH}
chmod -R 0775 ${RPM_PATH}

for I in $REPOSYNC_LIST2
do
	for J in x86_64 ppc64
	do
		if [[ $(ls ${RPM_PATH}/sles/${J}/*.rpm 2> /dev/null |wc -l) -ne 0 ]];then
			for W in $(ls ${RPM_PATH}/sles/${J}/*.rpm 2> /dev/null |awk -F"/" '{print $NF}')
			do					
				ssh ${I} "ls /fs/system/images/sles/sles11/updates/${J}Master11-SP4/ |grep ${W}" 
				if [[ $? -ne 0 ]];then
					scp -p ${RPM_PATH}/sles/${J}/${W} $I:/fs/system/images/sles/sles11/updates/${J}Master11-SP4/
				fi
			done
		fi
	done

	sum=0
	for U in $(ls ${RPM_PATH}/redhat7/*el7*.rpm 2> /dev/null)
	do
		ssh ${I} "ls ${RH7_REPO} |grep ${U##*/}"
		if [[ $? -ne 0 ]];then
			scp -p ${U} ${I}:${RH7_REPO}
			let sum+=1
		fi
	done
	[[ ${sum} -gt 0 ]] && echo "begin createrepo on ${I} for RHEL7" && ssh ${I} 'cd '${RH7_REPO}' && createrepo .'

	sum2=0
	for T in $(ls ${RPM_PATH}/redhat6/*el6*.rpm 2> /dev/null)
	do
		ssh ${I} "ls ${RH6_REPO} |grep ${T##*/}"
		if [[ $? -ne 0 ]];then
			scp -p ${T} ${I}:${RH6_REPO}
			let sum2+=1
		fi
	done
	[[ ${sum2} -gt 0 ]] && echo "begin createrepo on ${I} for RHEL6" && ssh ${I} 'cd '${RH6_REPO}' && createrepo .'	
done

## update rpms
if [[ $(ls -l ${RPM_PATH}/sles/x86_64/*.rpm 2> /dev/null |egrep -v "el6|el7" |wc -l) -ne 0 ]];then
	OS1=sles.x86_64
	RPM_LIST_LN=$(ls -l ${RPM_PATH}/sles/x86_64/*.rpm |egrep -v "el6|el7" |awk -F"/" '{print $NF}' |awk -F"x86_64|noarch" '{print $1}' |sed 's/.$//g' |xargs)
	RPM_LIST_SN=$(ls -l ${RPM_PATH}/sles/x86_64/*.rpm |egrep -v "el6|el7" |awk -F"/" '{print $NF}' |sed "s/\(.*\)-.*/\1/g" |sed 's/\(.*\)-.*/\1/g' |xargs)
	RPM_LIST2_LN=$(echo $RPM_LIST_LN |tr " " "|")
	RPM_LIST2_SN=$(echo $RPM_LIST_SN |sed 's/^/^/g' |sed 's/ /|^/g')

	A=$(echo ${RPM_LIST_LN} |awk '{print NF}')

	if [[ -n ${RPM_LIST_LN} ]];then
		for M in $(${SLES_X86_LIST} |egrep ^${PLEX})
		do
			echo "checking ${M}"
			B=$(ssh ${M} 'rpm -qa |egrep "'${RPM_LIST2_LN}'"' |wc -l)
			if [[ ${A} -eq ${B} ]];then
				echo "${M} updated already"
			else
				ssh $M "zypper refresh && zypper -n update ${RPM_LIST_LN}"
			fi
		done
	fi

	SUM1_DONE=0;TMP_SUM=0;for I in $(${SLES_X86_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_LN}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM1_DONE+=${TMP_SUM};done
	SUM1_ALL=0;TMP_SUM=0;for I in $(${SLES_X86_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_SN}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM1_ALL+=${TMP_SUM};done	
	SUM1_NONE=$(($SUM1_ALL-$SUM1_DONE))
fi

if [[ $(ls -l ${RPM_PATH}/sles/ppc64/*.rpm 2> /dev/null |egrep -v "el6|el7" |wc -l) -ne 0 ]];then
	OS2=sles.ppc64
	RPM_LIST_LN_2=$(ls -l ${RPM_PATH}/sles/ppc64/*.rpm |egrep -v "el6|el7" |awk -F"/" '{print $NF}' |awk -F"ppc64|noarch" '{print $1}' |sed 's/.$//g' |xargs)
	RPM_LIST_SN_2=$(ls -l ${RPM_PATH}/sles/ppc64/*.rpm |egrep -v "el6|el7" |awk -F"/" '{print $NF}' |sed "s/\(.*\)-.*/\1/g" |sed 's/\(.*\)-.*/\1/g' |xargs)
	RPM_LIST2_LN_2=$(echo $RPM_LIST_LN_2 |tr " " "|")
	RPM_LIST2_SN_2=$(echo $RPM_LIST_SN_2 |sed 's/^/^/g' |sed 's/ /|^/g')

	C=$(echo ${RPM_LIST_LN_2} |awk '{print NF}')

	if [[ -n ${RPM_LIST_LN_2} ]];then
		for N in $(${SLES_PPC64_LIST} |egrep ^${PLEX})
		do
			echo "checking ${N}"
			D=$(ssh ${N} 'rpm -qa |egrep "'${RPM_LIST2_LN_2}'"' |wc -l)
			if [[ ${C} -eq ${D} ]];then
				echo "${N} updated already"
			else
				ssh ${N} "zypper refresh && zypper -n update ${RPM_LIST_LN_2}"
			fi
		done
	fi

	SUM2_DONE=0;TMP_SUM=0;for I in $(${SLES_PPC64_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_LN_2}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM2_DONE+=${TMP_SUM};done
	SUM2_ALL=0;TMP_SUM=0;for I in $(${SLES_PPC64_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_SN_2}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM2_ALL+=${TMP_SUM};done	
	SUM2_NONE=$(($SUM2_ALL-$SUM2_DONE))
fi

if [[ $(ls -l ${RPM_PATH}/redhat7/*el7*.rpm 2> /dev/null |wc -l) -ne 0 ]];then
	OS3=RHEL7	
	RPM_LIST_LN_3=$(ls -l ${RPM_PATH}/redhat7/*el7*.rpm |awk -F"/" '{print $NF}' |sed 's/.rpm$//g' |xargs)
	RPM_LIST_SN_3=$(ls -l ${RPM_PATH}/redhat7/*el7*.rpm |awk -F"/" '{print $NF}' |sed "s/\(.*\)-.*/\1/g" |sed 's/\(.*\)-.*/\1/g' |xargs)
	RPM_LIST2_LN_3=$(echo $RPM_LIST_LN_3 |tr " " "|")
	RPM_LIST2_SN_3=$(echo $RPM_LIST_SN_3 |sed 's/^/^/g' |sed 's/ /|^/g')

	if [[ -n ${RPM_LIST_LN_3} ]];then
	
		for I in $(${RH7_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo $I;dssh -kn ${I} "yum clean all;yum -y --disablerepo=* --enablerepo=EI-*-update-* --enablerepo=*updates_${update_repo} --enablerepo=EI-*-base --enablerepo=rhel-upd* --nogpgcheck upgrade ${RPM_LIST_LN_3}";done	
	
	fi

	sleep 10	

	SUM3_DONE=0;TMP_SUM=0;for I in $(${RH7_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_LN_3}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM3_DONE+=${TMP_SUM};done
	SUM3_ALL=0;TMP_SUM=0;for I in $(${RH7_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_SN_3}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM3_ALL+=${TMP_SUM};done
	SUM3_NONE=$(($SUM3_ALL-$SUM3_DONE))
fi

if [[ $(ls -l ${RPM_PATH}/redhat6/*el6*.rpm 2> /dev/null |wc -l) -ne 0 ]];then
	OS4=RHEL6
	RPM_LIST_LN_4=$(ls -l ${RPM_PATH}/redhat6/*el6*.rpm |awk -F"/" '{print $NF}' |sed 's/.rpm$//g' |xargs)
	RPM_LIST_SN_4=$(ls -l ${RPM_PATH}/redhat6/*el6*.rpm |awk -F"/" '{print $NF}' |sed "s/\(.*\)-.*/\1/g" |sed 's/\(.*\)-.*/\1/g' |xargs)
	RPM_LIST2_LN_4=$(echo $RPM_LIST_LN_4 |tr " " "|")
	RPM_LIST2_SN_4=$(echo $RPM_LIST_SN_4 |sed 's/^/^/g' |sed 's/ /|^/g')

	if [[ -n ${RPM_LIST_LN_4} ]];then
		 	
		for I in $(${RH6_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo $I;dssh -kn ${I} "yum clean all;yum -y upgrade ${RPM_LIST_LN_4}";done

	fi

	SUM4_DONE=0;TMP_SUM=0;for I in $(${RH6_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_LN_4}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM4_DONE+=${TMP_SUM};done
	SUM4_ALL=0;TMP_SUM=0;for I in $(${RH6_LIST} |egrep ^${PLEX} |xargs -n50 |tr " " ",");do echo ${I};TMP_SUM=$(dssh -kn ${I} 'rpm -qa |egrep "'${RPM_LIST2_SN_4}'" 2> /dev/null' |cut -d":" -f1 |sort -n |uniq |wc -l);let SUM4_ALL+=${TMP_SUM};done	
	SUM4_NONE=$(($SUM4_ALL-$SUM4_DONE))
fi

echo
[[ -n ${OS1} ]] && echo -e "\033[32m ${SITE}_${OS1} should have ${SUM1_ALL} to update.and ${SUM1_DONE} have updated,${SUM1_NONE} did not update. \033[0m"
[[ -n ${OS2} ]] && echo -e "\033[32m ${SITE}_${OS2} should have ${SUM2_ALL} to update.and ${SUM2_DONE} have updated,${SUM2_NONE} did not update. \033[0m"
[[ -n ${OS3} ]] && echo -e "\033[32m ${SITE}_${OS3} should have ${SUM3_ALL} to update.and ${SUM3_DONE} have updated,${SUM3_NONE} did not update. \033[0m"
[[ -n ${OS4} ]] && echo -e "\033[32m ${SITE}_${OS4} should have ${SUM4_ALL} to update.and ${SUM4_DONE} have updated,${SUM4_NONE} did not update. \033[0m"
echo
