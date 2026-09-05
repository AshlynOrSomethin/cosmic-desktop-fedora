set dotenv-load

NAME := env('NAME')
TAG := 'nightly'

default:
    echo "default command does nothing"

all *FLAGS: clean (init FLAGS) sources spec build

all-srpm *FLAGS: clean (init FLAGS) sources spec build-srpm

# Requires python3
init *FLAGS:
    python3 scripts/cosmic-packaging-bootstrap.py {{ NAME }} --tag {{ TAG }} --input . --output testing {{ FLAGS }} 

# Make sure rpm tree is setup (rpmdev-setuptree)

# Install rpmdevtools
sources:
    mkdir -p ~/rpmbuild/SOURCES
    cp testing/vendor-* ~/rpmbuild/SOURCES/
    cp testing/*.patch ~/rpmbuild/SOURCES/ 2>/dev/null || true
    # download sources defined as URL in the specfile
    spectool -g -R testing/{{ NAME }}.spec

spec:
    mkdir -p ~/rpmbuild/SPECS
    cp testing/{{ NAME }}.spec ~/rpmbuild/SPECS/

install-dep:
    sudo dnf builddep ~/rpmbuild/SPECS/{{ NAME }}.spec

build:
    rpmbuild --undefine=_disable_source_fetch -bb ~/rpmbuild/SPECS/{{ NAME }}.spec

build-srpm:
    rpmbuild -bs ~/rpmbuild/SPECS/{{ NAME }}.spec

fast-build:
    rpmbuild -bb --short-circuit ~/rpmbuild/SPECS/{{ NAME }}.spec

clean:
    rm -rf testing

clean-rpmbuild-dir:
    rm -rf ~/rpmbuild
    rpmdev-setuptree

clone-upstream:
    #!/usr/bin/env bash
    set -ex
    rm -rf upstream/{{ NAME }}
    git clone https://src.fedoraproject.org/rpms/{{ NAME }}.git upstream/{{ NAME }}
    for p in $(ls patches/{{ NAME }}/*.patch 2>/dev/null | sort); do
        git -C upstream/{{ NAME }} am "../../$p"
    done

create-patch commit_msg:
    #!/usr/bin/env bash
    set -ex
    patch_name="$(echo "{{ commit_msg }}" | tr ' ' '_')"
    just create-patch "{{ commit_msg }}" "$patch_name"

create-patch-manual commit_msg patch_name:
    #!/usr/bin/env bash
    set -ex
    git -C upstream/{{ NAME }} add .
    git -C upstream/{{ NAME }} commit -m "{{ commit_msg }}"
    mkdir -p patches/{{ NAME }}
    next=$(printf "%04d" $(( $(ls -1 patches/{{ NAME }}/*.patch 2>/dev/null | wc -l) + 1 )))
    git -C upstream/{{ NAME }} format-patch -1 --stdout > patches/{{ NAME }}/${next}-{{ patch_name }}.patch
    git -C upstream/{{ NAME }} commit --amend --no-edit

push:
    git push upstream main
