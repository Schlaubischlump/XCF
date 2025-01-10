#!/bin/bash

#set -e

MIN_OSX_VERSION="10.15"

setupPkgConf()
{
    ARCH=$1
    shift 1
    
    DEPENDENCIES=("$@")
    
    # Setup the package config according to the dependencies.
    PKG_CONFIG_PATH=""
    for d in ${DEPENDENCIES[@]}; do
        if test "$d" = libssl ; then
            PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:$(echo ../openssl-apple-*/bin/MacOSX*-${ARCH}.sdk/lib/pkgconfig)
        else
            PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:../${d}/install/lib/pkgconfig
        fi
    done
    
    export PKG_CONFIG_PATH
}

###############################################
###     Run autogen / configure + make      ###
###############################################

build()
{
    if test -f "Makefile"; then
        make clean
    fi
    
    ARCH=$1
    TARGET=$2
    HOST=$3
    SDK=$4
    FLAGS=$5
        
    SDK_PATH=`xcrun -sdk ${SDK} --show-sdk-path`
    NUM_CPU=`sysctl -n hw.logicalcpu`

    CFLAGS="-arch ${ARCH} -target ${TARGET} -mmacosx-version-min=${MIN_OSX_VERSION} -isysroot ${SDK_PATH} -Wno-overriding-t-option"
        
    export CFLAGS
    export CXXFLAGS=${CFLAGS}
    export LDFLAGS=${CFLAGS}
    export CC="$(xcrun --sdk ${SDK} -f clang) ${CFLAGS}"
    export CXX="$(xcrun --sdk ${SDK} -f clang++) ${CFLAGS}"
    
    if test -f "autogen.sh"; then
        ./autogen.sh --host=${HOST} ${FLAGS}
    else
        ./buildconf
        ./configure --host=${HOST} ${FLAGS}
    fi
    make -j ${NUM_CPU}
    make install
}

###############################################
###        Make a library for MacOS         ###
###############################################

buildLibrary()
{
    ARCH=$1
    NAME=$2
    PREFIX=$4/install
    FLAGS="$3 --prefix=${PREFIX}"

    # Create the library output path and the path for make install
    mkdir -p ${PREFIX}
    mkdir -p ../${NAME}/lib/${ARCH}
    
    # Remove the obsolete prebind flag from configure.ac
    sed 's/,-prebind//g' configure.ac > configure.tmp
    rm configure.ac
    mv configure.tmp configure.ac
    
    # No idea... This works around some linker bug I guess. 
    # https://stackoverflow.com/questions/53121019/ld-bind-at-load-and-bitcode-bundle-xcode-setting-enable-bitcode-yes-cannot
    if test "$tagname" = CXX ; then
        case ${MACOSX_DEPLOYMENT_TARGET-10.0} in
            10.[0123])
                compile_command+=" ${wl}-bind_at_load"
                finalize_command+=" ${wl}-bind_at_load"
            ;;
        esac
    fi
    export MACOSX_DEPLOYMENT_TARGET="10.14.1"
    
    # build the project for the correct architecture
    build $ARCH "${ARCH}-apple-macos${MIN_OSX_VERSION}" "${ARCH}-apple-darwin" "macosx" "${FLAGS}" &> ../${LOG_FILE}
    
    # Copy the library to the corresponding folder
    TMP=(${PREFIX}/lib/*${NAME}*.a)
    cp ${TMP[0]} ../${NAME}/lib/${ARCH}/${NAME}.a
    #TMP=(${PREFIX}/lib/${NAME}-*.dylib)
    #cp ${TMP[0]} ../${NAME}/lib/${ARCH}/*${NAME}.dylib
}


###############################################
###              Merge Library              ###
###############################################

createXCF()
{
    NAME=$1
    lipo ${NAME}/lib/x86_64/${NAME}.a ${NAME}/lib/arm64/${NAME}.a \
        -create -output ${NAME}/lib/${NAME}.a
    xcodebuild -create-xcframework \
        -library ${NAME}/lib/${NAME}.a -headers ./include/${NAME} \
        -output ./frameworks/${NAME}.xcframework
}

###############################################
###     Download / Build / Merge Library    ###
###############################################


downloadProject() 
{
    REPO=$1
    NAME=$2
    VERSION=$3
    
    # Remove the build product folder if it already exists.
    if test -f ${NAME}; then
        rm -rf ${NAME}
    fi

    LOG_FILE="${NAME}-${VERSION}.log"
    PROJECT_DIR="${NAME}-${VERSION}"
    
    # Download the library file
    if [ ! -e ${PROJECT_DIR} ]; then
        echo "Cloning ${NAME}..."
        git clone --depth 1 --branch ${VERSION} https://github.com/${REPO}/${NAME} ${PROJECT_DIR} 
        return 0
    else
        echo "Using ${PROJECT_DIR}"
        return 1
    fi
}

buildProject()
{
    ARCH=$1
    NAME=$2
    VERSION=$3
    FLAGS=$4
    
    echo "Build library for arch $ARCH"
    
    # Read the last dependencies array element.
    shift 4
    DEPENDENCIES=("$@")
        
    LOG_FILE="${NAME}-${VERSION}.log"
    PROJECT_DIR="${NAME}-${VERSION}"
    INSTALL_PATH="$(pwd)/${NAME}"

    
    # Build the library file
    echo "Building ${NAME}..."
    
    pushd . > /dev/null
    
    cd ${PROJECT_DIR}
    
    setupPkgConf ${ARCH} "${DEPENDENCIES[@]}"
    buildLibrary ${ARCH} ${NAME} "${FLAGS}" ${INSTALL_PATH}
    
    popd > /dev/null
    
    echo "Done building ${NAME}"
}

###############################################
###    Function to build the dependencies   ###
###############################################

buildLibplist()
{
    ARCH=$1
    downloadProject "libimobiledevice" "libplist" "2.6.0"
    buildProject ${ARCH} "libplist" "2.6.0" "--disable-silent-rules --without-cython"
}


buildLibimobiledeviceGlue() 
{
    ARCH=$1
    downloadProject "libimobiledevice" "libimobiledevice-glue" "1.3.0"
    DEP=(
        "libplist"
    )
    buildProject ${ARCH} "libimobiledevice-glue" "1.3.0" "--disable-dependency-tracking --without-cython" "${DEP[@]}"
}


buildLibusbmuxd()
{
    ARCH=$1
    downloadProject "libimobiledevice" "libusbmuxd" "2.1.0"
    DEP=(
        #"libusb"
        "libplist",
        "libimobiledevice-glue"
    )
    buildProject ${ARCH} "libusbmuxd" "2.1.0" "--disable-dependency-tracking --without-cython --disable-silent-rules" "${DEP[@]}"
}

buildLibtatsu()
{
    ARCH=$1
    downloadProject "libimobiledevice" "libtatsu" "1.0.3"
    DEP=(
        #"libusb"
        "libplist"
    )
    buildProject ${ARCH} "libtatsu" "1.0.3" "--disable-dependency-tracking --without-cython --disable-silent-rules" "${DEP[@]}"
}

buildLibimobiledevice()
{
    ARCH=$1
    VERSION="master"
    PROJECT="libimobiledevice"
    
    downloadProject "SchlaubiSchlump" $PROJECT $VERSION
    
    # download the project
#    if downloadProject "SchlaubiSchlump" $PROJECT $VERSION ; then
        
        # patch t_math.c to add a missing include for never OpenSSL versions
#        echo "Patch t_math.c"
#        MATH_C=${PROJECT}-${VERSION}/3rd_party/libsrp6a-sha512/t_math.c
#        sed -i'' -e '/# include "openssl\/bn.h"/a\
# include "openssl\/rsa.h"\
#' "$MATH_C"

        # Looks like the flags inside the Makefile are missing libimobiledevice-glue
#        MAKEFILE_AM=${PROJECT}-${VERSION}/common/Makefile.am
#        echo "Patch AM_CFLAGS"
#        sed -i'' -e '/$(libusbmuxd_CFLAGS) \\/a\
#	$(limd_glue_CFLAGS) \\\
#' $MAKEFILE_AM
        
#        echo "Patch AM_LDFLAGS"
#        sed -i'' -e '/$(libusbmuxd_LIBS) \\/a\
#	$(limd_glue_LIBS) \\\
#' $MAKEFILE_AM        
#    fi
    
    DEP=(
        "curl"
        "libimobiledevice-glue"
        "libssl"
        "libplist"
        "libtatsu"
        "libusbmuxd"
    )
    buildProject ${ARCH} $PROJECT $VERSION "--disable-dependency-tracking --without-cython --disable-silent-rules --enable-debug-code" "${DEP[@]}"
}

buildLibusb()
{
    ARCH=$1
    downloadProject "libusb" "libusb" "v1.0.26"
    buildProject ${ARCH} "libusb" "v1.0.26" ""
}

buildLibSSL()
{
    ARCH=$1
    downloadProject "passepartoutvpn" "openssl-apple" "master"
    
    pushd . > /dev/null
    
    cd openssl-apple-*
    ./build-libssl.sh --version="3.2.0" --targets="macos64-${ARCH}"
    
    popd > /dev/null
}


buildCurl()
{
    ARCH=$1
    downloadProject "curl" "curl" "curl-8_2_1"
    DEP=(
        "libssl"
    )
    buildProject ${ARCH} "curl" "curl-8_2_1" "--with-openssl --disable-ntlm --disable-shared" "${DEP[@]}"
}


cleanup()
{
    #cleanup rm -rf lib*
    cleanup rm -rf *.log
    # TODO: Cleanup XCF
}

buildProjects()
{
    ARCH=$1
    echo "Build ${ARCH}..."
    buildLibSSL ${ARCH}
    buildLibplist ${ARCH}
    buildLibtatsu ${ARCH}
    buildLibimobiledeviceGlue ${ARCH}
    buildLibusb ${ARCH}
    buildLibusbmuxd ${ARCH}
    buildCurl ${ARCH}
    buildLibimobiledevice ${ARCH}
    
    echo "Done build ${ARCH}"
}

createProjectsXCF() {
    echo "Create xcframework..."
    
    pushd . > /dev/null
    cd openssl-apple-*
    ./create-openssl-framework.sh static    
    cp -r frameworks/*.xcframework ../frameworks
    popd > /dev/null
    
    createXCF "libplist"
    createXCF "libtatsu"
    createXCF "libusbmuxd"
    createXCF "libusb"
    createXCF "libimobiledevice-glue"
    createXCF "curl"
    createXCF "libimobiledevice"
    
    echo "Done creating xcframework"

}

###############################################
###         Main build instructions         ###
###############################################

# Note: It is important to first build all targets of one architecture. Otherwise the pkgconfig is broken.
buildProjects "arm64"
buildProjects "x86_64"
createProjectsXCF

