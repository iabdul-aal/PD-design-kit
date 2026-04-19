This folder contains the photodiode data exported for Lumerical `INTERCONNECT`.

Files:
- `ge_pd_interconnect_model_data.mat`: MATLAB source-data package aligned with the `photodetector_simple` compact-model template.
- `ge_pd_interconnect_resp.csv`: frequency-dependent responsivity table in `Hz, A/W`.
- `ge_pd_interconnect_bandwidth.csv`: bias-voltage vs 3 dB bandwidth table in `V, Hz`.
- `ge_pd_interconnect_dark_current.csv`: bias-voltage vs dark-current table in `V, A`.
- `ge_pd_interconnect_parameters.csv`: equivalent-circuit summary for quick reference.

Notes:
- The exported model is calibrated around the `-1 V` operating point used in this repo.
- The second bias point is duplicated as a starter template so the data can be imported into workflows that expect more than one bias sample.
- Replace the duplicated bias row with swept CHARGE data when full bias-dependent characterization is available.
