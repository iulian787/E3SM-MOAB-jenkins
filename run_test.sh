source /software/common/adm/packages/softenv-1.6.2/etc/softenv-load.sh
source /software/common/adm/packages/softenv-1.6.2/etc/softenv-aliases.sh
soft

soft add +gcc-6.2.0
soft add +mpich-3.2-gcc-6.2.0
soft add +szip-2.1-gcc-6.2.0
soft add +hdf5-1.8.16-gcc-6.2.0-mpich-3.2-parallel
soft add +netcdf-4.3.3.1c-4.2cxx-4.4.2f-parallel-gcc6.2.0-mpich3.2
soft add +pnetcdf-1.6.1-gcc-6.2.0-mpich-3.2
export PERL5LIB=/home/sarich/.perl/share/perl/5.18.2

set -x
testid=JENKINS
rm -rf e3sm_tests
mkdir e3sm_tests
mkdir e3sm_tests/$testid

if [ "x${WORKSPACE}" == "x" ]; then
    # Not using jenkins, get repos the old fashioned way
    # (For running this script manually)
    export WORKSPACE=/sandbox/sarich/jenkins
    cd ${WORKSPACE}
    if [ ! -d MOAB ]; then
	git clone https://bitbucket.org/fathomteam/moab.git MOAB
    fi
    cd MOAB
    git checkout master
    git fetch
    git reset --hard origin/master

    cd ${WORKSPACE}
    if [ ! -d E3SM ]; then
	git clone https://github.com/E3SM-Project/E3SM.git
    fi
    cd E3SM
    git checkout sarich/use-moab-driver
    git fetch
    git reset --hard origin/sarich/use-moab-driver
    git submodule init
    git submodule sync
    git submodule update
    sed -i "s^<MOAB_PATH>/home/sarich/software/anlworkstation/gcc-6.2-mpich-3.2/moab</MOAB_PATH>^<MOAB_PATH>${WORKSPACE}/MOAB-install</MOAB_PATH>^" cime/config/e3sm/machines/config_compilers.xml
fi

cd ${WORKSPACE}
cd MOAB
autoreconf -fi
rm -rf build
mkdir build
cd build
../configure --download-tempestremap=master --enable-debug CC=mpicc CXX=mpicxx F90=mpif90 F77=mpif77 FC=mpif90 --prefix=${WORKSPACE}/MOAB-install --with-zoltan=/home/sarich/software/anlworkstation/gcc-6.2-mpich-3.2/zoltan-3.83 --with-pic --without-vtk --disable-vtkMOABReader --with-eigen3=/home/sarich/software/eigen-3.3.7 --with-netcdf=/soft/apps/packages/climate/netcdf/4.3.3.1c-4.2cxx-4.4.2f-parallel/gcc-6.2.0 --with-netcdf-cxx=/soft/apps/packages/climate/netcdf/4.3.3.1c-4.2cxx-4.4.2f-parallel/gcc-6.2.0 --with-hdf5=/soft/apps/packages/climate/hdf5/1.8.16-parallel/gcc-6.2.0 --with-pnetcdf=/soft/apps/packages/climate/pnetcdf/1.6.1/gcc-6.2.0 --with-mpi=/soft/apps/packages/climate/mpich/3.2/gcc-6.2.0
retval=$?
if [ $retval -ne 0 ]; then
    echo "Error configuring MOAB"
    exit $retval
fi

make
retval=$?
if [ $retval -ne 0 ]; then
    echo "Error building MOAB"
    exit $retval
fi

make install
retval=$?
if [ $retval -ne 0 ]; then
    echo "Error installing MOAB"
    exit $retval
fi

make check

cd ${WORKSPACE}
cd E3SM
sed -i "s^<MOAB_PATH>/home/sarich/software/anlworkstation/gcc-6.2-mpich-3.2/moab</MOAB_PATH>^<MOAB_PATH>${WORKSPACE}/MOAB-install</MOAB_PATH>^" cime/config/e3sm/machines/config_compilers.xml
cd cime/scripts
./create_test SMS_Vmoab_Ln5.ne11_oQU240.A_WCYCL1850.anlworkstation_gnu --output-root ${WORKSPACE}/e3sm_tests --test-id $testid
./create_test ERS.f19_g16_rx1.A.anlworkstation_gnu --output-root ${WORKSPACE}/e3sm_tests --test-id $testid


timestamp=`date +"%Y%m%d_%H%M%S"`
# Try with different layout
./create_newcase --case ${WORKSPACE}/e3sm_tests/JENKINS/A_WCYCL1850_$timestamp --res ne11_oQU240 --compset A_WCYCL1850 --compiler gnu --driver moab --walltime 00:31:40 --output-root ${WORKSPACE}/e3sm_tests/JENKINS/A_WCYCL1850_$timestamp
cd ${WORKSPACE}/e3sm_tests/JENKINS/A_WCYCL1850_$timestamp
./xmlchange NTASKS=4
./xmlchange NTASKS_OCN=8
./xmlchange ROOTPE_OCN=8
./xmlchange ROOTPE_CPL=4
./case.setup
./case.build
./pelayout
./preview_run
./case.submit
