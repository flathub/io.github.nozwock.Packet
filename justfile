set ignore-comments

default: gen-sources validate-manifest

app_id := "io.github.nozwock.Packet"
manifest := app_id + ".yml"

validate-manifest:
    flatpak run org.flathub.flatpak-external-data-checker --edit-only "{{ manifest }}"

gen-sources:
    #!/usr/bin/env bash
    set -euo pipefail

    echo -e '\e[1mPulling git source...\e[0m'
    if [ -d .cache/packet/.git ]; then
        git -C .cache/packet pull
    else
        git clone https://github.com/nozwock/packet.git .cache/packet
    fi

    echo -e '\e[1mChecking out commit from manifest...\e[0m'
    # https://github.com/mikefarah/yq, go-yq
    REV="$(cat "{{ manifest }}" | yq -r '.modules[] | select(.name=="packet").sources.[0].commit')"
    git -C .cache/packet checkout "$REV"

    if [ ! -d .venv ]; then
        echo -e '\e[1mSetting up python environment and dependencies...\e[0m'
        python3 -m venv .venv
        source .venv/bin/activate
        pip install toml aiohttp
        deactivate
    fi

    echo -e '\e[1mGenerating cargo-sources.json\e[0m'
    source .venv/bin/activate
    python3 flatpak-builder-tools/cargo/flatpak-cargo-generator.py .cache/packet/Cargo.lock -o cargo-sources.json
    deactivate

