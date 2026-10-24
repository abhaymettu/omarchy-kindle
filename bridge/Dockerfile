FROM okarch:base
RUN sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf \
 && pacman-key --init && pacman-key --populate archlinuxarm \
 && pacman -Syu --noconfirm --needed base-devel git wayland wayland-protocols wlr-protocols mesa libdrm libglvnd qt6-base \
 && pacman -Scc --noconfirm
WORKDIR /src
