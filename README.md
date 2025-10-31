# RAT-Remote-Arm-Technology----ROS2-code-using-docker-compose
<br>
This guide provides a robust, step-by-step process for setting up the ROS 2 Jazzy simulation environment for the OpenManipulator-X robot, resolving common dependency and container-sourcing issues encountered during compilation and launch.  


Setup Steps

1. Clone the Repository and Workspace

Navigate to your development directory and clone the necessary repository. This repository contains all the packages we need.

# Clone the open_manipulator repository (using the main branch for Jazzy)
git clone [https://github.com/ROBOTIS-GIT/open_manipulator.git](https://github.com/ROBOTIS-GIT/open_manipulator.git)
cd open_manipulator

# Move the source code to the expected workspace location for the Docker setup
mkdir -p ../ws/src
mv * ../ws/src/
cd ../ws


2. Launch the Development Container

We will use docker compose to build and launch the container with the necessary volume mounts for your host machine's X11 server (for Gazebo GUI).

Host Terminal Command:

# Build the image and start the container in detached mode
docker compose up -d --build


The running container will be named open_manipulator_jazzy (or similar, depending on your setup).

3. Access the Container and Fix Dependencies

We use a special docker exec command to ensure the ROS 2 Jazzy environment (/opt/ros/jazzy/setup.bash) is sourced correctly upon entry, and then we run dependency installation.

Host Terminal Command (to enter the container):

docker exec -it open_manipulator_jazzy /bin/bash -c "source /opt/ros/jazzy/setup.bash && /bin/bash"


Once inside the container (root@...:/home/user/ws#):

A. Dependency Resolution (Fixing E: Unable to locate package)

The base Docker image often has repository configuration conflicts. We must clean up the apt sources and manually re-add the ROS key and repository source to allow rosdep to find packages like xacro and moveit.

# 1. Clean up conflicting source files and keys
rm -f /etc/apt/sources.list.d/ros2.list /etc/apt/sources.list.d/ros.list
rm -f /usr/share/keyrings/ros-archive-keyring.gpg

# 2. Re-add the clean ROS GPG key
curl -sSL [https://raw.githubusercontent.com/ros/rosdistro/master/ros.key](https://raw.githubusercontent.com/ros/rosdistro/master/ros.key) -o /usr/share/keyrings/ros-archive-keyring.gpg

# 3. Add the clean ROS 2 source list for Ubuntu Noble (Jazzy)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] [http://packages.ros.org/ros2/ubuntu](http://packages.ros.org/ros2/ubuntu) $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# 4. Update apt and install all missing system dependencies via rosdep
apt update
rosdep update
rosdep install --from-paths src --ignore-src -r -y
sudo apt install ros-jazzy-moveit-configs-utils   
apt install ros-jazzy-moveit -y  
apt install -y ros-jazzy-hardware-interface ros-jazzy-joint-state-broadcaster ros-jazzy-joint-trajectory-controller
sudo apt install ros-${ROS_DISTRO}-backward-ros -y
  
(Always try to get rosdep to get to work and only then turn to apt if nothing works out)

4. Build the Workspace

After dependencies are successfully installed, compile the workspace. We limit parallel workers to 2 to avoid hitting system limits that cause compilation failures.

Container Command:

colcon build --symlink-install --parallel-workers 2



Prerequisites
Ensure the following tools are installed on your host Ubuntu machine:
1. Git: For cloning the repository.
2. Docker & Docker Compose: For building and running the containerized environment (requires X11 forwarding setup for Gazebo to display).



<h1>common fixes--</h1>
<br>
This is the biggest hurdle we have faced yet! Thank you for providing the full output.

The New, Major Problem: Repository Access
The error is not that the packages are missing; the error is:

E: Unable to locate package ros-jazzy-xacro
E: Unable to locate package ros-jazzy-moveit-core
...
This indicates that your container's package manager (apt) cannot find the necessary ROS 2 Jazzy packages in the default Debian repositories or the ROS official repositories.

This is happening because:

The base osrf/ros:jazzy-desktop image only installs the core packages it needs.

Your local workspace depends on many other common ROS 2 packages (moveit, ros2_control components, etc.) that are not pre-installed.

The source list used by apt inside the container is missing or incomplete, or the repository keys are missing, preventing it from fetching packages like ros-jazzy-xacro and all the moveit dependencies.

The Fix: Re-add the ROS Repositories
We need to make sure the standard ROS 2 repositories are properly set up and keyed inside your container environment so apt can find all those ros-jazzy-* packages.

Since you are running as root (which simplifies things), we can perform the full repository setup sequence.

Step 1: Re-add ROS 2 Repository Keys and Sources
Execute these three commands sequentially inside your container shell (root@sundeep-MS-7C52:/home/user/ws#):



# 1. Update system to ensure latest certs
apt update -y

# 2. Install necessary tools and set up locale
apt install -y software-properties-common wget curl lsb-release locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# 3. Add the ROS 2 GPG key
    # 1. Clear out all potential ROS source files in sources.list.d
        rm -f /etc/apt/sources.list.d/ros2.list
        rm -f /etc/apt/sources.list.d/ros.list

    # 2. Check for, and remove, the specific signed-by file that apt is complaining about.
        rm -f /usr/share/keyrings/ros-archive-keyring.gpg
        curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
Step 2: Add the ROS 2 Source to the List


# Add the ROS 2 Jazzy repository source
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
Step 3: Run apt update and rosdep install Again
Now that the source lists are clean and complete, update apt and re-run rosdep install.



# Update the package index with the new sources
apt update

# Re-run rosdep install (it will now find the packages)
rosdep install --from-paths src --ignore-src -r -y
This full setup process should resolve the repository access issue and allow rosdep to install all the missing packages, including xacro and moveit-core. Let me know the output of the final rosdep install command!




     [rviz2-2] qt.qpa.xcb: could not connect to display :0
This means the container lacks the necessary access and configuration to display graphical output on your host's X server.

The Standard Fix: X11 Forwarding Configuration
To solve this, we need to perform two steps outside of the container (on your host machine) and then one step inside the container.

Step 1: Host Setup - Grant Access to the Container (Action on your Host Machine)
You need to grant permission for any application running on your host to connect to your X server.

On your host machine's terminal (outside the container), run:

Bash

xhost +local:docker
This command temporarily allows local Docker containers to connect to your display. If this fails, try the simpler xhost +.

Step 2: Container Launch - Pass Environment Variables (Action on your Host Machine)
When launching the container, you must ensure three critical environment variables and the X11 socket are passed into the container. Since I cannot re-run your container for you, you will need to re-run your docker run or docker-compose up command, ensuring these arguments are included:

If you are using docker run, your command needs to look something like this:

Bash

docker exec -it \
    --env="DISPLAY" \
    --env="QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    <your-image-name>
Note: Since you are using a workspace directory, you likely already have a -v mount for your code.

Step 3: Relaunch the Full System (Action Inside the Container)
Once you have stopped your current container and launched a new one with the correct display forwarding (Steps 1 & 2), the GUI applications should no longer crash.



[0.316s] ERROR:colcon:colcon build: Duplicate package names not supported: - open_manipulator_moveit_config: - src/open_manipulator/open_manipulator_moveit_config - src/open_manipulator_controls/open_manipulator_moveit_config

fix: mv /home/user/ws/src/open_manipulator_controls/open_manipulator_moveit_config /home/user/




We will now run the robust MoveIt launch file, assuming the display issue is fixed, and Rviz2 should appear:

Bash

# Inside the container shell
ros2 launch open_manipulator_moveit_config open_manipulator_x_moveit.launch.py use_sim:=true <your-image-name>
