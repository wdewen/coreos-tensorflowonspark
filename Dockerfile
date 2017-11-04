FROM gcr.io/tensorflow/tensorflow:latest-gpu
MAINTAINER Damien Broka <damienbroka@mailbox.org>

ARG HADOOP_VERSION
ARG SPARK_VERSION
ARG SPARKHADOOP_VERSION

RUN add-apt-repository ppa:kelleyk/emacs && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
	emacs25-nox \
	git \
	openjdk-8-jre \
	openjdk-8-jdk \
	wget \
	etcd \
	jq \
	screen \
	&& \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip --no-cache-dir install \
	pymongo \
	scikit-image \
	blaze \
	flake8 \
	jedi \
	keras \
	tensorflowonspark \
	py4j \
	&& \
    python -m ipykernel.kernelspec

## temporary fix for tensorflowonspark pulling cpu version of tf
RUN yes | pip --no-cache-dir uninstall \
    	      tensorflow \
	      tensorflow-gpu && \
    pip --no-cache-dir install \
    	tensorflow-gpu

RUN useradd -ms /bin/bash user
COPY --chown=user setup-emacs.el /home/user/.emacs.d/setup-emacs.el
COPY --chown=user emacs.el /home/user/.emacs
RUN runuser -u user -- emacs --batch --script /home/user/.emacs.d/setup-emacs.el

WORKDIR /tmp
ENV HADOOP_MIRROR http://apache.mirrors.ionfish.org/hadoop/common/hadoop-${HADOOP_VERSION}
ENV HADOOP_ARCHIVE hadoop-${HADOOP_VERSION}
RUN wget ${HADOOP_MIRROR}/${HADOOP_ARCHIVE}.tar.gz
RUN wget https://dist.apache.org/repos/dist/release/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_ARCHIVE}.tar.gz.mds && \
    echo $(cat /tmp/${HADOOP_ARCHIVE}.tar.gz.mds | grep MD5 | cut -d: -f2 | cut -d= -f2 | sed -e 's/ //g') ${HADOOP_ARCHIVE}.tar.gz > ${HADOOP_ARCHIVE}.tar.gz.mds && \
    md5sum -c ${HADOOP_ARCHIVE}.tar.gz.mds


ENV SPARK_ARCHIVE spark-${SPARK_VERSION}-bin-hadoop${SPARKHADOOP_VERSION}
ENV SPARK_MIRROR http://apache.osuosl.org/spark/spark-${SPARK_VERSION}
RUN wget ${SPARK_MIRROR}/${SPARK_ARCHIVE}.tgz
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_ARCHIVE}.tgz.md5 && \
    echo $(cat /tmp/${SPARK_ARCHIVE}.tgz.md5 | cut -d: -f2 | sed -e 's/ //g') ${SPARK_ARCHIVE}.tgz > ${SPARK_ARCHIVE}.tgz.md5 && \
    md5sum -c ${SPARK_ARCHIVE}.tgz.md5

RUN useradd -G user -s /bin/nologin spark

RUN mkdir -p /opt/hadoop && \
    tar -C /tmp -zxvf /tmp/${HADOOP_ARCHIVE}.tar.gz && \
    mv /tmp/${HADOOP_ARCHIVE}/* /opt/hadoop && \
    mkdir -p /opt/apache-spark && \
    tar -C /tmp -zxvf /tmp/${SPARK_ARCHIVE}.tgz && \
    mv /tmp/${SPARK_ARCHIVE}/* /opt/apache-spark

# dropin fix for dirty update of etcd to current (compatible with coreos alpha channel)
ENV ETCD_VER=v3.2.8
ENV GITHUB_ETCD_URL=https://github.com/coreos/etcd/releases/download

RUN mkdir -p /tmp/etcd && \
    curl -L ${GITHUB_ETCD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd --strip-components=1 && \
    rm /usr/bin/etcd* && \
    ln -s /tmp/etcd/etcd  /usr/bin/etcd && \
    ln -s /tmp/etcd/etcdctl /usr/bin/etcdctl 

COPY apache-spark.sh /etc/profile.d/apache-spark.sh
COPY hadoop.sh /etc/profile.d/hadoop.sh

#COPY run-unprivileged.sh /
#WORKDIR "/home/user"
#CMD /run-unprivileged.sh

#EXPOSE 8080 7077 8888 8081 4040 7001 7002 7003 7004 7005 7006

COPY ./sparkonetcd.sh /opt/sparkonetcd.sh
COPY ./spark-defaults.conf /opt/apache-spark/conf/spark-defaults.conf

ENV NODE_IP=
ENV DISCOVERY_TOKEN=

RUN chown -R spark:spark /opt
WORKDIR /opt
CMD /opt/sparkonetcd.sh ${NODE_IP} ${DISCOVERY_TOKEN}
