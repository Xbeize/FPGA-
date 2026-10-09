# HX4S20C HDMI Player

Open `hx4s20c_hdmi_player_v2.al` in Tang Dynasty 6.2.1. Download the exact
board-confirmed bitstream at `release/hx4s20c_hdmi_player_verified.bit` to
FPGA RAM. Generated TD run directories are not included in this repository.

The player scans physical TF-card sectors 0 through 131071 for up to four
640 x 480, 24-bit uncompressed BMP images. It uses SDRAM double buffering and
outputs video and stereo audio through **HDMI B**. KEY1 selects the next image;
KEY2 toggles automatic playback. The user confirmed the picture, both keys,
and the audio on the board. The audio is a 48 kHz sine-wave C4-D4-E4-F4-G4-
A4-B4-C5 scale, half a second per note. ACR timing starts at reset; PCM and
the melody start two seconds after the first image is committed. The 24-bit
PCM peak is `0x400000` (about -6 dBFS).

The board-confirmed release bitstream has SHA-256:

```text
A1FC5EE96BD373CEEF3A23EBF5927E83ABFD608293125188B46E6037ED0DF2D1
```

## Build

```powershell
& .\scripts\build_td.ps1 -TdRoot '<your Tang Dynasty installation directory>'
iverilog -g2012 -s tb_audio_sine_scale -o tb\tb_audio_sine_scale.vvp tb\tb_audio_sine_scale.v user_source\hdl_source\audio_sine_scale_48k.v user_source\hdl_source\audio_arc_calculate.v
vvp tb\tb_audio_sine_scale.vvp
iverilog -g2012 -s tb_bmp_scan -o tb\tb_bmp_scan.vvp tb\tb_bmp_scan.v user_source\hdl_source\SD\bmp_read.v
vvp tb\tb_bmp_scan.vvp
```

The merged project completed synthesis, place and route, STA, and BitGen for
EG4S20BG256. Final setup WNS is **+0.381 ns** and hold WNS is **+0.003 ns**.
The SDRAM controller runs at 50 MHz with a 198-degree output clock; its
refresh interval was updated to match. The TF and HDMI clocks remain 100 MHz
and 25/125 MHz. The original SDC has no external input/output delay
constraints, so this STA result is not complete board-level timing proof.

Rebuilding this project produces a new bitstream under
`hx4s20c_hdmi_player_v2_Runs/phy_1`. Its hash may differ from the
board-confirmed release bitstream; test a rebuilt bitstream on the board before
replacing the release file. Configuration Flash boot/power-cycle behavior has
not yet been confirmed.

This repository includes Anlogic-generated IP, the encrypted HDMI transmitter
core, and HDL adapted from the supplied reference examples so that the TD
project can be built. Their original copyright notices remain in place. No
license for those third-party components is granted by this repository; check
the vendor's terms before redistributing or reusing them elsewhere.
