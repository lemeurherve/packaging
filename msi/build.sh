#!/bin/bash -ex
export PATH=~/tools/native/wix:/cygdrive/c/Program\ Files/Windows\ Installer\ XML\ v3.5/bin:$PATH

war="$1"
ENCODEDVERSION="$2"
ARTIFACTNAME="$3"
PRODUCTNAME="$4"
PORT="$5"
if [ "" == "$PORT" ]; then
  echo "build.sh path/to/jenkins.war version artifactName port"
  exit 1
fi

rm -rf tmp || true
mkdir tmp || true
unzip -p "$war" 'WEB-INF/lib/jenkins-core-*.jar' > tmp/core.jar
unzip -p tmp/core.jar windows-service/jenkins.exe > tmp/jenkins.exe
unzip -p tmp/core.jar windows-service/jenkins.xml | sed -e "s|\bjenkins\b|${ARTIFACTNAME}|" | sed -e "s|8080|${PORT}|" > tmp/jenkins.xm_
# replace executable name to the bundled JRE
sed -e 's|executable.*|executable>%BASE%\\jre\\bin\\java</executable>|' < tmp/jenkins.xm_ > tmp/jenkins.xml

# capture JRE
javac FindJava.java
JREDIR=$(java -cp . FindJava)
echo "JRE=$JREDIR"
heat dir "$JREDIR" -o jre.wxs -sfrag -sreg -nologo -srd -gg -cg JreComponents -dr JreDir -var var.JreDir

# pick up java.exe File ID
JavaExeId=$(grep java.exe jre.wxs | grep -o "fil[0-9A-F]*")

# version
v=$(unzip -p "$war" META-INF/MANIFEST.MF | grep Implementation-Version | cut -d ' ' -f2 | tr -d '\r' | sed -e "s/-SNAPSHOT//" | sed -e "s/-beta-.*//")
echo version=$v

candle -dVERSION=$v -dENCODEDVERSION=${ENCODEDVERSION} -dJreDir="$JREDIR" -dWAR="$war" -dJavaExeId=$JavaExeId -nologo -ext WixUIExtension -ext WixUtilExtension -ext WixFirewallExtension jenkins.wxs jre.wxs
# '-sval' skips validation. without this, light somehow doesn't work on automated build environment
# set to -dcl:low during debug and -dcl:high for release
light -o ${ARTIFACTNAME}-$v.msi -sval -nologo -dcl:high -ext WixUIExtension -ext WixUtilExtension -ext WixFirewallExtension ${ARTIFACTNAME}.wixobj jre.wixobj

msbuild.exe /property:src=${ARTIFACTNAME}-$v.msi "/property:ProductName=${PRODUCTNAME}" bootstrapper.xml

zip ${ARTIFACTNAME}-$v-windows.zip ${ARTIFACTNAME}-$v.msi setup.exe

# avoid bringing back files that we don't care
rm -rf tmp *.class *.wixpdb *.wixobj