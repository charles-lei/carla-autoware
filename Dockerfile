ARG AUTOWARE_VERSION=1.14.0-melodic-cuda
FROM autoware/autoware:$AUTOWARE_VERSION
RUN sed -i 's#http://archive.ubuntu.com/#http://mirrors.tuna.tsinghua.edu.cn/#' /etc/apt/sources.list \
    && sed -i 's#https#http#' /etc/apt/sources.list.d/cuda.list
USER autoware
WORKDIR /home/autoware

# Update simulation repo to latest master.
RUN git clone --recurse-submodules https://github.com.cnpmjs.org/charles-lei/carla-autoware.git
# This will pull very large map data, and may take a long time
RUN sudo apt update && sudo apt upgrade && sudo apt-get install git-lfs \
    && cd carla-autoware \
    && git checkout 0.9.10 \
    && cp update_sim.patch ~/Autoware/ \
    && cd autoware-contents \
    && git lfs pull

RUN patch ./Autoware/autoware.ai.repos ./Autoware/update_sim.patch \
    && cd ./Autoware \
    && vcs import src < autoware.ai.repos \
    && git --git-dir=./src/autoware/simulation/.git --work-tree=./src/autoware/simulation pull \
    && source /opt/ros/melodic/setup.bash \
    && AUTOWARE_COMPILE_WITH_CUDA=1 colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# CARLA PythonAPI
RUN git clone https://github.com/charles-lei/PythonAPI.git
RUN echo "export PYTHONPATH=\$PYTHONPATH:~/PythonAPI/carla/dist/carla-0.9.10-py2.7-linux-x86_64.egg" >> .bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:~/PythonAPI/carla" >> .bashrc

# CARLA ROS Bridge
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        python-pip \
        python-wheel \
        ros-melodic-ackermann-msgs \
        ros-melodic-derived-object-msgs \
    && sudo rm -rf /var/lib/apt/lists/*
RUN pip install -i https://pypi.tuna.tsinghua.edu.cn/simple simple-pid pygame networkx==2.2

RUN git clone --recurse-submodules https://github.com/charles-lei/ros-bridge.git

RUN mkdir -p carla_ws/src
RUN cd carla_ws/src \
    && ln -s ../../ros-bridge \
    && ln -s ../../carla-autoware/carla-autoware-agent \
    && cd .. \
    && source /opt/ros/melodic/setup.bash && catkin_make

RUN echo "export CARLA_AUTOWARE_CONTENTS=~/autoware-contents" >> .bashrc \
    && echo "source ~/carla_ws/devel/setup.bash" >> .bashrc \
    && echo "source ~/Autoware/install/setup.bash" >> .bashrc \
    && echo "export ROS_HOSTNAME=localhost"

CMD ["/bin/bash"]

