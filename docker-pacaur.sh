#!/bin/sh
set -ue

NAME="vpalazzo/pacaur"
# FROM_NAME="vpalazzo/archlinux:2019.02.01"
FROM_NAME="archlinux/base"
OUTDIR="./pkgs"

ENTRYPOINT='#!/bin/sh
if [ "$#" -eq 0 ]; then
    echo Ready.
    cd
    exec /bin/bash -l
else
    . /etc/profile
    sudo pacman --noconfirm -Suy &&\
    EDITOR=/usr/bin/true \
    pacaur --noconfirm --noedit --rebuild --foreign --makepkg "$@" &&\
    sudo find ~/.cache/pacaur -mindepth 2 -maxdepth 2 -type f \
         -iname "*.pkg.tar.xz" -exec sh -c '"'"'
                cp "$1" "$2"/pkgs/ &&\
                chown "$3":"$4" "$2"/pkgs/"$(basename "$1")"
    '"'"' - {} "$HOME" "${DOCKER_CLIENT_USER}" "${DOCKER_CLIENT_GROUP}" \;
fi
'

DOCKERFILE='
FROM '"$FROM_NAME"'

RUN \
    pacman --noconfirm --needed --sync --refresh sed &&\
    pacman --noconfirm --needed --sync --refresh --sysupgrade \
           expac yajl git base-devel perl

RUN \
    ln -nfs /usr/share/zoneinfo/Europe/Rome /etc/localtime &&\
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen &&\
    echo "LANG=en_US.UTF-8" >/etc/locale.conf &&\
    locale-gen &&\
    useradd -m user &&\
    echo "user ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/user

USER user

RUN \
    . /etc/profile &&\
    gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53 &&\
    mkdir /tmp/pacaur_install &&\
    cd /tmp/pacaur_install &&\
    for aur in cower pacaur; do \
        git clone https://aur.archlinux.org/"$aur".git &&\
        cd "$aur" &&\
        makepkg --syncdeps --install --noconfirm &&\
        cd .. || exit 1 ;\
    done &&\
    cd &&\
    sudo rm -rf /tmp/pacaur_install

RUN \
    echo '"'$(echo "$ENTRYPOINT" | base64 --wrap=0)'"' |\
        base64 --decode |\
        sudo tee /entrypoint.sh >/dev/null &&\
    sudo chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
'

echo "$DOCKERFILE" | docker build --force-rm --tag "$NAME" -

mkdir -p "$OUTDIR"
echo 'Start building....'
docker run --tty --interactive --rm \
       --env DOCKER_CLIENT_USER="$(id -u)" \
       --env DOCKER_CLIENT_GROUP="$(id -g)" \
       --volume "$(readlink -f "$OUTDIR")":/home/user/pkgs \
       "$NAME" "$@"
