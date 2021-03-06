#!/bin/bash
set -evx

while true; do echo .; sleep 60; done &

sudo fallocate -l 4GB /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

if [[ $TRAVIS_PULL_REQUEST == "false" ]]; then
    BRANCH=$TRAVIS_BRANCH
    MAVEN_PHASE="deploy"
else
    BRANCH=$TRAVIS_PULL_REQUEST_BRANCH
    MAVEN_PHASE="install"
fi

if ! git -C $TRAVIS_BUILD_DIR/.. clone https://github.com/deeplearning4j/libnd4j/ --depth=50 --branch=$BRANCH; then
     git -C $TRAVIS_BUILD_DIR/.. clone https://github.com/deeplearning4j/libnd4j/ --depth=50
fi

PROTOBUF=3.5.1
curl --retry 10 -L https://github.com/google/protobuf/releases/download/v$PROTOBUF/protobuf-cpp-$PROTOBUF.tar.gz -o $HOME/protobuf-$PROTOBUF.tar.gz
tar -C $TRAVIS_BUILD_DIR/.. --totals -xf $HOME/protobuf-$PROTOBUF.tar.gz

if [[ -n "${EXT:-}" ]]; then
    DEVTOOLSET=6
else
    DEVTOOLSET=4
fi

if [[ -n "${CUDA:-}" ]]; then
    DOCKER_IMAGE=nvidia/cuda:$CUDA-devel-centos6
else
    DOCKER_IMAGE=centos:6
fi

docker run -ti -e SONATYPE_USERNAME -e SONATYPE_PASSWORD -v $HOME/.m2:/root/.m2 -v $TRAVIS_BUILD_DIR/..:/build $DOCKER_IMAGE /bin/bash -evxc "\
    yum -y install centos-release-scl-rh epel-release; \
    yum -y install devtoolset-$DEVTOOLSET-toolchain rh-maven33 cmake3 git java-1.8.0-openjdk-devel; \
    source scl_source enable devtoolset-$DEVTOOLSET rh-maven33 || true; \
    cd /build/protobuf-$PROTOBUF/; \
    ./configure; \
    make -j2; \
    cd /build/libnd4j/; \
    sed -i /cmake_minimum_required/d CMakeLists.txt; \
    MAKEJ=2 bash buildnativeoperations.sh -c cpu -e ${EXT:-}; \
    if [[ -n \"${CUDA:-}\" ]]; then \
        MAKEJ=1 bash buildnativeoperations.sh -c cuda -v $CUDA -cc 30; \
    fi; \
    cd /build/nd4j/; \
    if [[ -n \"${CUDA:-}\" ]]; then \
        bash change-cuda-versions.sh $CUDA; \
        EXTRA_OPTIONS='-pl !nd4j-uberjar'; \
    else \
        EXTRA_OPTIONS='-pl !nd4j-uberjar,!nd4j-backends/nd4j-backend-impls/nd4j-cuda,!nd4j-backends/nd4j-backend-impls/nd4j-cuda-platform,!nd4j-backends/nd4j-tests'; \
    fi; \
    bash change-scala-versions.sh $SCALA; \
    mvn clean $MAVEN_PHASE -B -U --settings ./ci/settings.xml -Dmaven.test.skip=true -Dlocal.software.repository=sonatype \
        -Djavacpp.extension=${EXT:-} \$EXTRA_OPTIONS -DprotocCommand=/build/protobuf-$PROTOBUF/src/protoc;"

