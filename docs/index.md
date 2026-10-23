# LNCD EEG pre-processing pipeline

## Outline
1. Remark EEG data
2. Pre-processing pipeline
    1. Rereference to mastoids [run_filtering.m]()
    2. Bandpass filter 0.5-70 Hz [run_iltering.m]()
    3. Notch filter at 60 Hz [run_filtering.m]()
    4. Downsample data to 512 Hz [run_filtering.m]()
    5. Channel rejction [run_channel_rejection.m]()
    6. Channel interpolation [run_channel_interpolation.m]()
    7. Generate ICA weights on downsampled data
    8. Apply ICA weights to original EEG data
    9. Run ICA rejection [run_autoICA_rejection.m]() or [run_manualICA_rejection.m]()
    10. Generate QC file
3. Epoch data
    1. Clean epochs [epochclean.m[()

## Code documentation
**Remarking**

**Reference to mastoids**

**Bandpass filter**

**Notch filter**

**Downsample**

**Channel rejection**

**Channel interpolation**

**Generate ICA weights**

**Apply ICA weights**

**Run ICA rejection**

**Generate QC file**

**Generate epochs**

