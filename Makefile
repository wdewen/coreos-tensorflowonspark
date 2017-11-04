HADOOP_VERSION=2.7.4
SPARKHADOOP_VERSION=2.7
SPARK_VERSION=2.2.0

gpu:
	sudo docker build --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
		          --build-arg SPARK_VERSION=$(SPARK_VERSION) \
			  --build-arg SPARKHADOOP_VERSION=$(SPARKHADOOP_VERSION) \
			  -t brokad/coreos-tensorflowonspark:latest-gpu -f Dockerfile .

gpu-py3:
	sudo docker build --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
		          --build-arg SPARK_VERSION=$(SPARK_VERSION) \
			  --build-arg SPARKHADOOP_VERSION=$(SPARKHADOOP_VERSION) \
			  -t brokad/coreos-tensorflowonspark:latest-gpu-py3 -f Dockerfile.python3 .

cpu:
	sudo docker build --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
		          --build-arg SPARK_VERSION=$(SPARK_VERSION) \
			  --build-arg SPARKHADOOP_VERSION=$(SPARKHADOOP_VERSION) \
			  -t brokad/coreos-tensorflowonspark:latest -f Dockerfile.cpu .

cpu-py3:
	sudo docker build --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
		          --build-arg SPARK_VERSION=$(SPARK_VERSION) \
			  --build-arg SPARKHADOOP_VERSION=$(SPARKHADOOP_VERSION) \
			  -t brokad/coreos-tensorflowonspark:latest-py3 -f Dockerfile.cpu.py3 .


all: gpu cpu gpu-py3 cpu-py3

push:
	sudo docker push brokad/coreos-tensorflowonspark:latest
	sudo docker push brokad/coreos-tensorflowonspark:latest-gpu
	sudo docker push brokad/coreos-tensorflowonspark:latest-gpu-py3
	sudo docker push brokad/coreos-tensorflowonspark:latest-py3
