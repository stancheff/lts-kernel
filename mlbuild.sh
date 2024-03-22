#!/bin/bash

### ToDo:
### Make script smart enough to find .nosrc.rpm templates outside of PWD

# Default TARGET kernel is LTS 5.16.7 so:

KMAJOR=6
KMINOR=6
KPATCH=1

# Current TEMPLATE / SPEC file to patch is 5.14.21
SPEC_MAJOR=6
SPEC_MINOR=6
SPEC_PATCH=1
# SPEC_BUILD=1

MIRROR=https://mirrors.edge.kernel.org/pub/linux/kernel
# + v5.x/

# GCOV=gcov.
GCOV=

RWITH=${RPMBUILD_OPT}
RDEF=

ELVER=elU
if [[ -f /etc/redhat-release ]] ; then
	if grep -q 'release 9' /etc/redhat-release ; then ELVER=el9; fi
	if grep -q 'release 8' /etc/redhat-release ; then ELVER=el8; fi
	if grep -q 'release 7' /etc/redhat-release ; then ELVER=el7; fi
fi

myprog_help()
{
	echo "Usage: $(basename ${0}) [OPTIONS]"
	echo $'\n'"Builds kernel package of linux kernel"
	echo $'\n'"Available options:"
	echo " --mirror <url>     -- kernel.org mirror to use"
	echo " --major <version>  -- kernel major version [default ${KMAJOR}]"
	echo " --minor <version>  -- kernel minor version [default ${KMINOR}]"
	echo " --patch <version>  -- patch version [default ${KPATCH}]"
	echo " --build <number>   -- build number [default None]"
	echo " --gcov [gcov.]     -- build/expect coverage enabled (default '${GCOV}')"
	echo " --os <elN>         -- specify OS major release (default '${ELVER}')"
	echo " --without <arg>    -- passed to rpmbuild"
	echo "                       Ex: --without bpftool --without doc"
	echo "                           --without tools --without perf"
	echo " --with <arg>       -- passed to rpmbuild"
	if [ "x$RWITH" != "x" ] ; then
	echo "              ---> '$RWITH'"
	fi
	echo " --define <arg>     -- passed to rpmbuild"
	echo "                       Ex: --define '%dist my_tag'"
	echo ""
	echo "Ex:"
	echo "./mlbuild.sh --major 5 --minor 14 --patch 21 --gcov gcov."
	echo ""
}


while [ "${1}" ] ; do
	case "${1}" in
		--mirror)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide a kernel.org mirror with --mirror" >&2
			fi
			MIRROR="${1}"
			shift
			;;
		--major)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide the target kernel major version with --major" >&2
			fi
			KMAJOR="${1}"
			shift
			;;
		--minor)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide the target kernel minor version with --minor" >&2
			fi
			KMINOR="${1}"
			shift
			;;
		--patch)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide the target kernel patch version with --patch" >&2
			fi
			KPATCH="${1}"
			shift
			;;
		--build)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide the target kernel build number --build" >&2
			fi
			KBUILD="${1}"
			if [[ $KBUILD == "+1" ]]; then
				_val=$(cat _kernel_build)
				KBUILD=$((_val + 1))
			fi
			echo "$KBUILD" '>' _kernel_build
			echo "$KBUILD" > _kernel_build
			shift
			;;
		--os)
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Please provide the OS version with --os" >&2
			fi
			ELVER="${1}"
			shift
			;;
		--gcov)
			shift
			if [[ ! "${1}" ]] ; then
				echo "Not using/building a gcov. enabled kernel"
				GCOV=""
			else
				GCOV="${1}"
				echo "Expecting to use/build a gcov. enabled kernel"
			fi
			shift
			;;
		--with|--without)
			switch="${1}"
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Argument requried for ${switch}" >&2
			fi
			RWITH="${RWITH} ${switch} ${1}"
			shift
			;;
		--define)
			switch="${1}"
			shift
			if [[ ! "${1}" ]] ; then
				error_out 2 "Argument requried for ${switch}" >&2
			fi
			RDEF="${RDEF} ${switch} '${1}'"
			shift
			;;
		--help)
			myprog_help
			exit 0
			;;
		*)
			echo "Error: Unknown option '${1}'." >&2
			myprog_help >&2
			exit 2
			;;                  
	esac
done

WGET=$(which wget)
if [[ -z ${WGET} ]] ; then
	echo "Missing wget."
	exit 3
fi

SPEC_VERSION=${SPEC_MAJOR}.${SPEC_MINOR}.${SPEC_PATCH}
if [[ -n ${SPEC_BUILD} ]] ; then
	SPEC_VERSION="${SPEC_VERSION}.${SPEC_BUILD}"
fi
RPM_BASE=kernel-${SPEC_VERSION}-1.${GCOV}ldiskfs.${ELVER}.nosrc.rpm
if [[ ! -f ${RPM_BASE} ]] ; then
	echo Missing ${RPM_BASE}
	exit 3
fi
rpm -ivh ${RPM_BASE}

HERE=${PWD}
KVERSION=${KMAJOR}.${KMINOR}.${KPATCH}
KSRC=linux-${KVERSION}
KTARBALL=${KSRC}.tar.xz
mkdir -p .cache
if [[ -n ${KBUILD} ]] ; then
	KVERSION="${KVERSION}.${KBUILD}"
	echo cd ${HOME}
	cd ${HOME}
	echo tar cf --exclude-vcs ${HERE}/linux.tar linux
	tar --exclude-vcs -cf ${HERE}/linux.tar linux
	echo cd ${HERE}
	cd ${HERE}
	echo mv -v linux.tar .cache
	mv -v linux.tar .cache
	KSRC=linux
	KTARBALL=${KSRC}.tar
fi 
if [[ -f .cache/${KTARBALL} ]] ; then
	cp -v .cache/${KTARBALL} .
else
	echo wget ${MIRROR}/v${KMAJOR}.x/${KTARBALL}
	wget ${MIRROR}/v${KMAJOR}.x/${KTARBALL}
	cp ${KTARBALL} .cache
fi
echo tar xf ${KTARBALL}
tar xf ${KTARBALL}
if [[ -n ${KBUILD} ]] ; then
	echo mv linux linux-${KVERSION}
	mv linux linux-${KVERSION}
	KSRC=linux-${KVERSION}
	KTARBALL=${KSRC}.tar.xz
fi
echo make oldconfig from ${HOME}/rpmbuild/SOURCES/config-${SPEC_VERSION}-x86_64
echo cp ${HOME}/rpmbuild/SOURCES/config-${SPEC_VERSION}-x86_64 ${KSRC}/.config
cp ${HOME}/rpmbuild/SOURCES/config-${SPEC_VERSION}-x86_64 ${KSRC}/.config
echo cd ${KSRC}
cd ${KSRC}
echo yes "" '|' make oldconfig
yes "" | make oldconfig
echo cp .config ${HOME}/rpmbuild/SOURCES/config-${KVERSION}-x86_64
cp .config ${HOME}/rpmbuild/SOURCES/config-${KVERSION}-x86_64
touch ${HOME}/rpmbuild/SOURCES/config-${KVERSION}-aarch64
echo cd ..
cd ..
if [[ -n ${KBUILD} ]] ; then
	KSRC=linux-${KVERSION}
	KTARBALL=${KSRC}.tar.xz
	echo tar cf linux-${KVERSION}.tar ${KSRC}
	tar cf linux-${KVERSION}.tar ${KSRC}
	echo xz --threads=0 linux-${KVERSION}.tar
	xz --threads=0 linux-${KVERSION}.tar
fi
rm -fr ${KSRC}
mv ${KTARBALL} ${HOME}/rpmbuild/SOURCES
echo Patching spec for ${KVERSION}
echo cd ${HOME}/rpmbuild/SPECS
cd ${HOME}/rpmbuild/SPECS
echo cp kernel-${SPEC_VERSION}+${GCOV}ldiskfs.spec kernel-${KVERSION}+${GCOV}ldiskfs.spec
cp kernel-${SPEC_VERSION}+${GCOV}ldiskfs.spec kernel-${KVERSION}+${GCOV}ldiskfs.spec
sed -i -e "s/LKAver ${SPEC_VERSION}/LKAver ${KVERSION}/" \
       -e "s/{LKAver}.${SPEC_PATCH}/{LKAver}.${KPATCH}/" \
          kernel-${KVERSION}+${GCOV}ldiskfs.spec
echo rpmbuild ${RDEF} ${RWITH} -ba kernel-${KVERSION}+${GCOV}ldiskfs.spec
rpmbuild ${RDEF} ${RWITH} -ba kernel-${KVERSION}+${GCOV}ldiskfs.spec
cd ${HERE}
