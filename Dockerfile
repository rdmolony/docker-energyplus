FROM ubuntu:18.04 AS base

# This is not ideal. The tarballs are not named nicely and EnergyPlus versioning is strange
ENV ENERGYPLUS_INSTALL_VERSION=9-1-0
ENV ENERGYPLUS_VERSION=9.1.0
ENV ENERGYPLUS_TAG=v$ENERGYPLUS_VERSION
ENV ENERGYPLUS_SHA=08d2e308bb

# Downloading from Github
# e.g. https://github.com/NREL/EnergyPlus/releases/download/v8.3.0/EnergyPlus-8.3.0-6d97d074ea-Linux-x86_64.sh
ENV ENERGYPLUS_DOWNLOAD_BASE_URL https://github.com/NREL/EnergyPlus/releases/download/$ENERGYPLUS_TAG
ENV ENERGYPLUS_DOWNLOAD_FILENAME EnergyPlus-$ENERGYPLUS_VERSION-$ENERGYPLUS_SHA-Linux-x86_64.sh
ENV ENERGYPLUS_DOWNLOAD_URL $ENERGYPLUS_DOWNLOAD_BASE_URL/$ENERGYPLUS_DOWNLOAD_FILENAME

# Download apt dependencies
RUN apt-get update && apt-get install -y ca-certificates curl libx11-6 libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Download E+
RUN curl -SLO $ENERGYPLUS_DOWNLOAD_URL
  
# Install E+
RUN chmod +x $ENERGYPLUS_DOWNLOAD_FILENAME \
    && echo "y\r" | ./$ENERGYPLUS_DOWNLOAD_FILENAME 

# Move all E+ files into EnergyPlus-9-1-0 folder
RUN cd /usr/local \
    && mkdir EnergyPlus-$ENERGYPLUS_INSTALL_VERSION \
    && mv Bugreprt.txt ExpandObjects SetupOutputVariables.csv ep.gif DataSets \ 
    LICENSE.txt WeatherData readme.html workflows Documentation MacroDataSets \
    runenergyplus EPMacro OutputChanges9-0-0-to-9-1-0.md changelog.html runepmacro \
    Energy+.idd PostProcess energyplus lib runreadvars Energy+.schema.epJSON \
    PreProcess energyplus-9.1.0 libenergyplusapi.so sbin ExampleFiles \
    Rules9-0-0-to-9-1-0.md energyplus.1 libenergyplusapi.so.9.1.0 \
    EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/

# Remove a bunch of the auxiliary apps/files
# that are not needed in the container 
RUN rm $ENERGYPLUS_DOWNLOAD_FILENAME \ 
   && cd /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION \
   && rm -rf DataSets Documentation ExampleFiles WeatherData MacroDataSets PostProcess/convertESOMTRpgm \
   PostProcess/EP-Compare PreProcess/FMUParser PreProcess/ParametricPreProcessor PreProcess/IDFVersionUpdater

# Remove the broken symlinks
RUN cd /usr/local/bin \
    && find -L . -type l -delete

# Add in the test files
ADD test /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/test_run
RUN cp /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/Energy+.idd \
    /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/test_run/

# Use Multi-stage build to produce a smaller final image
FROM debian:buster-slim

COPY --from=base /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/ /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION/
COPY --from=base /usr/local/bin /usr/local/bin

VOLUME /var/simdata/energyplus
WORKDIR /var/simdata/energyplus

CMD [ "/bin/bash" ]
