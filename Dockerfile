FROM scratch
MAINTAINER Jon Chen <docku@burrito.sh>
ADD root.tar.xz /
RUN /usr/bin/pacman -Syu --needed --noconfirm \
    git strace screen tree vim \
    inetutils iproute2 iputils net-tools \
    lsof net-tools procps-ng psmisc mtr zsh
CMD ["/sbin/init"]

