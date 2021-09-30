# Configure Docker to listen on a TCP socket
mkdir /etc/systemd/system/docker.service.d

# https://stackoverflow.com/a/42204921/12089368
# https://dev.to/dhwaneetbhatt/run-docker-without-docker-desktop-on-macos-306h
echo '[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock' > /etc/systemd/system/docker.service.d/docker.conf

echo '{
  "hosts": ["fd://", "tcp://0.0.0.0:2375"]
}' > /etc/docker/daemon.json

systemctl daemon-reload
systemctl restart docker.service
