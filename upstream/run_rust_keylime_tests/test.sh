#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

    rlPhaseStartSetup "Do the keylime setup"
        rlRun 'rlImport "./test-helpers"' || rlDie "cannot import keylime-tests/test-helpers library"
        if [ -d /var/tmp/rust-keylime_sources ]; then
            rlLogInfo "Missing upstream rust keylime sources."
        else
            rlDie "Upstream keylime sources must be already downloaded."
        fi
        # if TPM emulator is present
        if limeTPMEmulated; then
            # start tpm emulator
            rlRun "limeStartTPMEmulator"
            rlRun "limeWaitForTPMEmulator"
            # make sure tpm2-abrmd is running
            rlServiceStart tpm2-abrmd
            sleep 5
            # start ima emulator
            rlRun "limeInstallIMAConfig"
            rlRun "limeStartIMAEmulator"
        fi
        rlRun "pushd /var/tmp/rust-keylime_sources"
        # install for measuring code coverage
        if [ "${KEYLIME_RUST_CODE_COVERAGE}" == "1" -o "${KEYLIME_RUST_CODE_COVERAGE}" == "true" ]; then
            rlRun "cargo install cargo-tarpaulin"
        fi
    rlPhaseEnd

    rlPhaseStartTest "Run cargo tests"
        rlRun "cargo test --features testing -- --nocapture"
    rlPhaseEnd

    if [ "${KEYLIME_RUST_CODE_COVERAGE}" == "1" -o "${KEYLIME_RUST_CODE_COVERAGE}" == "true" ]; then
        rlPhaseStartTest "Run cargo tests and measure code coverage"
            #run cargo tarpaulin code coverage
            rlRun "cargo tarpaulin -v --target-dir target/tarpaulin --workspace --exclude-files 'target/*' --ignore-panics --ignore-tests --out Xml --out Html --all-features"
            rlRun "tar --create --file upstream_coverage.tar tarpaulin-report.html"
            rlRun "mv cobertura.xml upstream_coverage.xml"
            rlFileSubmit upstream_coverage.xml
            rlFileSubmit upstream_coverage.tar
            rlRun "mv upstream_coverage.xml upstream_coverage.tar ${__INTERNAL_limeCoverageDir}"
        rlPhaseEnd
    fi

    rlPhaseStartCleanup "Do the keylime cleanup"
        rlRun "popd"
        if limeTPMEmulated; then
            rlRun "limeStopIMAEmulator"
            rlRun "limeStopTPMEmulator"
            rlServiceRestore tpm2-abrmd
        fi
    rlPhaseEnd

rlJournalEnd