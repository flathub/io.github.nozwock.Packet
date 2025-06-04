set ignore-comments

default: gen-vendor validate-manifest

app_id := "io.github.nozwock.Packet"
rev := "9c4ed86b"

validate-manifest:
    flatpak run org.flathub.flatpak-external-data-checker --edit-only "{{ app_id }}.json"

gen-vendor:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC=".cache/packet"
    VENDOR_TAR="packet-vendor.tar"

    echo -e '\e[1mPulling git source...\e[0m'
    if [ -d "$SRC"/.git ]; then
        git -C "$SRC" pull
    else
        git clone https://github.com/nozwock/packet.git "$SRC"
    fi

    echo -e '\e[1mChecking out commit...\e[0m'
    git -C "$SRC" checkout "{{ rev }}"

    echo -e '\e[1mCleaning git work root...\e[0m'
    git -C "$SRC" clean -fdx

    # DIST is relative to SOURCE_ROOT
    echo -e '\e[1mVendoring dependencies...\e[0m'
    bash "$SRC"/build-aux/dist-vendor.sh '../' "$SRC/src"

    echo -e '\e[1mArchiving git work root...\e[0m'
    git -C "$SRC" archive --format tar "{{ rev }}" > "$VENDOR_TAR"
    tar --append --file "$VENDOR_TAR" -C "$SRC" .cargo vendor
    echo -e '\e[1mCompressing tarball...\e[0m'
    xz -fz "$VENDOR_TAR"

    VENDOR_TAR="$VENDOR_TAR.xz"
    SHA256="$(sha256sum "$VENDOR_TAR" | cut -d' ' -f1)"
    echo -e "\e[1mUpdating sha256 in Flatpak manifest to $SHA256\e[0m"
    cat "{{ app_id }}.json" |
    jq \
        --indent 4 \
        '(.modules[] | select(.name == "packet").sources[0].sha256) = '"\"$SHA256\"" \
    >manifest.new
    mv manifest.new "{{ app_id }}.json"
