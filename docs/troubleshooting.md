# Troubleshooting

## ReaImGui Is Missing

Install `ReaImGui: ReaScript binding for Dear ImGui` from ReaPack, then restart REAPER.

## Backend Is Missing

If the window says the backend is missing, the ReaPack package did not install completely.

Try:

1. `Extensions -> ReaPack -> Synchronize packages`.
2. Update `REAPER Audio Tag`.
3. Restart REAPER.

The backend should be installed under:

```text
REAPER/Data/reaper-panns-item-report/bin/
```

## Model Download Failed

Click `Download Model` again. The download is verified by file size and SHA-256, so a partial or corrupted download is rejected safely.

Expected model:

```text
cnn14_waveform_clipwise_opset17.onnx
sha256 deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa
```

The model is about 327 MB. A slow connection can make the first download take a while.

## Checksum Mismatch

Delete the broken model file from:

```text
REAPER/Data/reaper-panns-item-report/models/
```

Then run `REAPER Audio Tag` and click `Download Model` again.

## First macOS Run Is Slow

On macOS, CoreML can compile and cache the model the first time it runs. Later runs should be faster.

## GPU Is Not Used

The backend tries the native accelerator first:

- macOS: CoreML;
- Windows: DirectML.

If that provider is unavailable or fails, the backend falls back to CPU so analysis can still finish.

## Analysis Does Not Start

Make sure exactly one audio item is selected before running `REAPER Audio Tag`.

## Debug Export

Use `REAPER Audio Tag - Debug Export` if you need to check whether REAPER can export the selected item into the temporary WAV used by the backend.
