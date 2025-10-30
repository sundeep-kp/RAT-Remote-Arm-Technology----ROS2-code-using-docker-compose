# We use a standard ROS 2 Jazzy image as the base.
FROM osrf/ros:jazzy-desktop

# --- 1. USER SYNC STRATEGY (CRITICAL FIX) ---
# We perform setup as 'root' (default user) and switch to the assumed
# non-root user 'user' (UID 1000) only for the final CMD execution 
# to ensure file permissions match the host, avoiding build failure.

# --- 2. WORKSPACE PREP ---
# NOTE: Commands run as root. Paths reference the non-root user's home '/home/user'.
WORKDIR /home/user

# The 'ws' directory will be mounted by the host's persistent 'ros2_ws' folder.
RUN mkdir -p ws/src
WORKDIR /home/user/ws/src

# --- 3. INSTALL DEPENDENCIES (MANUALLY RUN THIS LATER) ---
WORKDIR /home/user/ws

# --- 4. SETUP SHELL (CRITICAL AUTO-SOURCING) ---
# Source the main ROS setup file permanently for the 'user' account.
RUN echo "source /opt/ros/jazzy/setup.bash" >> /home/user/.bashrc
# Source the local workspace setup (needed after the first successful colcon build).
RUN echo "if [ -f /home/user/ws/install/setup.bash ]; then source /home/user/ws/install/setup.bash; fi" >> /home/user/.bashrc

# --- 5. FINAL RUNTIME USER ---
# Switch to the non-root user (UID 1000) for security and correct file permissions
# on the mounted volumes.
USER user

CMD ["/bin/bash"]

