FROM ubuntu:23.10

WORKDIR /root
COPY models models
COPY properties properties
COPY lnverifier .
COPY Makefile .

RUN apt-get update &&\
    apt-get install -y bison byacc curl gcc make
RUN curl -O https://spinroot.com/spin/Archive/spin651.tar.gz &&\
    gunzip spin651.tar.gz &&\
    tar -xf spin651.tar &&\
    cd Src* &&\
    make &&\
    cp spin /usr/local/bin

ENTRYPOINT ["bash", "lnverifier"]
