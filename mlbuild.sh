#!/bin/bash

### ToDo:
### Make script smart enough to find .nosrc.rpm templates outside of PWD

# Default TARGET kernel is LTS 5.16.7 so:

KMAJOR=5
KMINOR=16
KPATCH=7

# Current TEMPLATE / SPEC file to patch is 5.14.21

SPEC_MAJOR=5
SPEC_MINOR=14
SPEC_PATCH=21

MIRROR=https://mirrors.edge.kernel.org/pub/linux/kernel
# + v5.x/

# GCOV=gcov.
GCOV=

ELVER=el8
[[ $(uname -r | grep -q '.el9.') ]] && ELVER=el9
[[ $(uname -r | grep -q '.el8.') ]] && ELVER=el8
[[ $(uname -r | grep -q '.el7.') ]] && ELVER=el7

myprog_help()
{
	echo "Usage: $(basename ${0}) [OPTIONS]"
	echo $'\n'"Builds kernel package of linux kernel"
	echo $'\n'"Available options:"
	echo " --mirror <url>     -- kernel.org mirror to use"
	echo " --major <version>  -- kernel major version (default ${KMAJOR})"
	echo " --minor <version>  -- kernel minor version (default ${KMINOR})"
	echo " --patch <version>  -- patch version (default ${KPATCH})"
	echo " --gcov [gcov.]     -- build/expect coverage enabled (default '${GCOV}')"
	echo " --os <elN>         -- specify OS major release (default '${ELVER}'"
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

SPEC_VERSION=${SPEC_MAJOR}.${SPEC_MINOR}.${SPEC_PATCH}

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
if [[ -f .cache/${KTARBALL} ]] ; then
	cp .cache/${KTARBALL} .
else
	echo wget ${MIRROR}/v${KMAJOR}.x/${KTARBALL}
	wget ${MIRROR}/v${KMAJOR}.x/${KTARBALL}
	cp ${KTARBALL} .cache
fi
echo tar xf ${KTARBALL}
tar xf ${KTARBALL}
echo make oldconfig from ${HOME}/rpmbuild/SOURCES/config-${SPEC_VERSION}-x86_64
cp ${HOME}/rpmbuild/SOURCES/config-${SPEC_VERSION}-x86_64 ${KSRC}/.config
cd ${KSRC}
yes "" | make oldconfig
cp .config ${HOME}/rpmbuild/SOURCES/config-${KMAJOR}.${KMINOR}.${KPATCH}-x86_64
cd ..
rm -fr ${KSRC}
mv ${KTARBALL} ${HOME}/rpmbuild/SOURCES
echo Patching spec for ${KVERSION}
sed -i -e "s/LKAver ${SPEC_VERSION}/LKAver ${KVERSION}/" \
       -e "s/{LKAver}.${SPEC_PATCH}/{LKAver}.${KPATCH}/" \
  ${HOME}/rpmbuild/SPECS/kernel-${SPEC_MAJOR}.${SPEC_MINOR}+${GCOV}ldiskfs.spec

cd ${HOME}/rpmbuild/SPECS
rpmbuild -ba kernel-${SPEC_MAJOR}.${SPEC_MINOR}+${GCOV}ldiskfs.spec
