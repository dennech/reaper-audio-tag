# Internal Runtime Maintenance

These notes are for developers and recovery work only.

Normal users should not follow this document. The public install flow is:

- install the script with ReaPack
- install `ReaImGui`
- install Python `3.11`
- create a local venv and install the pinned dependencies
- download `Cnn14_mAP=0.431.pth`
- run `REAPER Audio Tag: Configure`

The commands below remain available only for source checkouts, local maintenance, and recovery:

For a packaged internal bootstrap:

```bash
./scripts/bootstrap.command
```

For local development with editable installs:

```bash
./scripts/bootstrap_runtime.sh --dev
```

Both helpers can download and prepare a managed runtime for checkout/recovery scenarios. They are intentionally kept out of the public REAPER install docs.
