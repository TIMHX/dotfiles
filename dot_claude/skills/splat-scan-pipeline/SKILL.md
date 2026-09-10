---
name: splat-scan-pipeline
description: Receives a phone LiDAR scan (SplatKing app export) over a local upload channel, then runs it through COLMAP SfM → Brush Gaussian Splatting → NKSR collision mesh to produce a visual splat .ply and a low-poly collider .obj — for any object or room scan, not just one specific project. Trigger on requests like "开个上传通道", "开上传端口给我传scan", "process my splatking scan", "跑一下高斯泼溅管线", "新建一个splat项目", or when a `LidarSeries_*.zip` / SplatKing export shows up and needs to become a Gaussian-splat asset (VRChat, general 3D asset, or otherwise).
---

# Phone-scan → Gaussian Splat pipeline

General-purpose pipeline for turning a SplatKing-app LiDAR scan of **any object or
room** into a visual Gaussian-splat `.ply` and a simplified collision `.obj`. Not tied to
one project or one capture — re-run this for every new scan. Originally developed and
debugged against a real desk scan on 2026-09-01; the specific pitfalls hit along the way
are written up in the `~/llmwikis/3d-sim-wiki` pages `splatking-lidar-vrchat-pipeline`
and `colmap-gpu-headless-mesh-gotchas` for deeper background.

**Standing principle**: always take the full-quality path, never a scaled-down
compromise, and explain before taking any impactful/hard-to-reverse action (sudo
installs, overwriting files, remounting drives, opening a network listener). If a
GPU/best-practice path looks blocked, diagnose the root cause before falling back to a
weaker method — don't assume the environment is limited (e.g. headless) without checking.

## Hard constraints

- Default to `~/gaussgym/` as the working project unless told otherwise; ask if it's
  ambiguous which project a new scan belongs to. Never delete existing files.
- Retry a failing step at most 3x, then log the failure and continue to the next
  independent step rather than blocking forever.
- Never fabricate results (file sizes, registration rates, vertex/face counts) — read
  them from actual command output/logs.
- Long-running steps (upload server, COLMAP mapper, Brush training, NKSR) MUST run in
  the background, never foreground-blocking:
  `setsid nohup <cmd> < /dev/null > logfile 2>&1 & disown`
  A bare `nohup cmd &` is not reliably enough — it can still be SIGTERM'd when the parent
  session restarts. `setsid` + `disown` fully detaches. Poll the log file / process table
  instead of waiting synchronously.
- Each new scan gets its own directory under `<project>/data/<scan_name>/`, and its own
  `<project>/output/<scan_name>/` for deliverables — don't overwrite a previous scan's
  outputs when starting a new one.

## Step 0 — Open the upload channel

When the user says something like "开上传通道" / "给我一个上传地址" they mean: start a
local HTTP listener they can POST the scan zip to from their phone or SplatKing's export
flow, over LAN (e.g. `http://192.168.0.58:8000/upload`).

```
mkdir -p <project>/data/incoming
setsid nohup python3 ~/.claude/skills/splat-scan-pipeline/scripts/upload_server.py \
    <project>/data/incoming 8000 \
    < /dev/null > <project>/logs/upload_server.log 2>&1 & disown
```
Find the LAN IP to give the user with `hostname -I` or `ip addr`, and tell them the
exact URL (`http://<ip>:8000/upload`) plus that it accepts either a `multipart/form-data`
POST with a `file` field, or a raw body with an `X-Filename` header (covers curl,
Shortcuts-style uploads, or a custom app upload action).

Poll `<project>/data/incoming/` for the new file — watch the size stop changing (large
captures take a while over Wi-Fi) before treating the upload as complete, then move on to
Step 1. Once the pipeline for a scan has started, it's fine to leave the upload server
running in case the user wants to send another scan next.

## Step 1 — Unzip and verify structure

```
cd <project>/data && unzip -q incoming/<capture>.zip -d <scan_name> && ls <scan_name>/
```
Expected SplatKing LiDAR-mode layout:
- `COLMAP_Text_Model/sparse/0/{cameras,images,points3D}.txt` — SplatKing/ARKit **device
  poses**, explicitly not bundle-adjusted (see its own README.txt). **Do not train Brush
  directly on this.** It exists only as an image folder + fallback reference.
- `COLMAP_Text_Model/images/*.jpg`
- `lidar_pointcloud_world_xyz.ply` / `.bin` — world-frame LiDAR point cloud, the NKSR input.
- `capture_events.ndjson` — grep for `"paused"`/`"resumed"` to check for mid-capture relocations (see Step 3 note).
- `sensor_data/`, `photo_series.json` — not needed for this pipeline.

If the structure differs (different app, different export mode), note it and adapt paths accordingly.

## Step 2 — Check for a real display before assuming headless

**Do not assume the machine is headless.** Before falling back to CPU-only COLMAP or
installing Xvfb, check for an already-running GPU-capable X session:
```
echo $DISPLAY; who; loginctl list-sessions; ps aux | grep -i xorg
```
If a real session exists (e.g. `DISPLAY=:0` with a GNOME/X11 session in `loginctl`),
export `DISPLAY` and `XAUTHORITY` (typically `/run/user/<uid>/gdm/Xauthority`) for the
COLMAP commands below and use real GPU OpenGL — this is dramatically faster (14s vs.
~5min for feature extraction on a ~700-image set) and is the correct, non-compromise
path. Only if no display genuinely exists should Xvfb be considered, and that requires
explaining the tradeoff to the user first (sudo install) rather than silently doing it.

## Step 3 — Real COLMAP SfM (never skip this)

**This is the step most likely to be skipped by mistake — verify no shortcut trains
Brush directly on `COLMAP_Text_Model` before treating existing outputs as valid.**

```
mkdir -p <project>/colmap_ws/<scan_name> && cd <project>/colmap_ws/<scan_name>
ln -s <project>/data/<scan_name>/COLMAP_Text_Model/images images

# 1. Feature extraction — GPU (OpenGL SiftGPU), num_threads capped to avoid SQLite locks
DISPLAY=:0 XAUTHORITY=/run/user/$(id -u)/gdm/Xauthority \
  setsid nohup colmap feature_extractor \
    --database_path scan.db --image_path images \
    --SiftExtraction.use_gpu 1 --SiftExtraction.max_image_size 3200 \
    --SiftExtraction.num_threads 4 \
    < /dev/null > ../../logs/colmap_feature_<scan_name>.log 2>&1 & disown

# 2. Sequential matcher — GPU. Use sequential (not exhaustive) for a walk-around/
#    circular capture pattern, which SplatKing LiDAR captures typically are.
DISPLAY=:0 XAUTHORITY=/run/user/$(id -u)/gdm/Xauthority \
  setsid nohup colmap sequential_matcher \
    --database_path scan.db --SiftMatching.use_gpu 1 \
    < /dev/null > ../../logs/colmap_match_<scan_name>.log 2>&1 & disown

# 3. Mapper — CPU only. COLMAP's incremental SfM (RANSAC pose estimation,
#    triangulation, global bundle adjustment via Ceres Solver) has NO GPU path in
#    COLMAP's architecture — this is not an environment shortcoming, don't try to force GPU here.
mkdir -p sparse
setsid nohup colmap mapper --database_path scan.db --image_path images \
    --output_path sparse \
    < /dev/null > ../../logs/colmap_mapper_<scan_name>.log 2>&1 & disown
```

Verify success: `colmap model_converter --input_path sparse/0 --output_path sparse/0
--output_type TXT`, then check registration rate in the mapper log / `sparse/0/images.txt`
(target: as close to 100% as possible, single `sparse/0` model with no fragmentation into
`sparse/1`, `sparse/2`, …).

**Mid-capture pause/relocation check**: grep `capture_events.ndjson` for pause/resume
events. Because this pipeline re-derives poses from real COLMAP SfM (not raw ARKit
world-tracking), a short pause-and-relocate during capture does not by itself corrupt the
reconstruction — confirm by checking the registration rate stayed near 100% and the
model didn't fragment.

## Step 4 — Brush training (visual splat)

```
setsid nohup brush_app <project>/colmap_ws/<scan_name> \
    --total-steps 10000 --export-every 1000 \
    --export-path <project>/output/<scan_name>/brush_train \
    < /dev/null > <project>/logs/brush_train_<scan_name>.log 2>&1 & disown
```
- Point Brush at the **COLMAP output directory** (`colmap_ws/<scan_name>`), never at
  `COLMAP_Text_Model` directly.
- **Absolutely no `init.ply`** — seeding from the raw LiDAR point cloud anchors noise and
  produces fuzzy artifacts (confirmed by the user's own prior testing). Confirm no
  init.ply was loaded by checking the Brush log for a VFS mount line like `plys: 0`.
- Poll progress with `tail -f` on the log or by watching `export_*.ply` appear in the
  export dir.
- Acceptance thresholds for the final export (`export_10000.ply`): **<1MB = failed,
  re-scan**; **20–50MB = acceptable**; **50MB+ = good**. Copy the final export to
  `<project>/output/<scan_name>/<scan_name>_splat.ply`.

## Step 5 — NKSR collision mesh

```
<project>/.venv/bin/python <project>/splatking_to_nksr.py \
    --input <project>/data/<scan_name>/lidar_pointcloud_world_xyz.ply \
    --output <project>/output/<scan_name>/<scan_name>_mesh.ply
```
Runs on GPU, typically well under a minute for a room-scale scan. Record vertex/face
counts and watertightness from the script's own output — don't guess.

## Step 6 — Simplify to a collision-ready `.obj` (<20k faces)

NKSR output is usually non-watertight with many small disconnected fragments (scan
noise). **Do not reach for `open3d.simplify_quadric_decimation` or
`fast_simplification` alone as the primary method** — both stall well above the target
face count (observed: plateaus at 70–90% reduction, never near <20k) because they
conservatively refuse to collapse edges near boundaries on non-manifold geometry, no
matter how aggressive the setting.

The reliable method:
1. Remove small disconnected components first via `open3d`'s
   `mesh.cluster_connected_triangles()` (NOT `trimesh.split()` — that OOMs on
   multi-million-face meshes). Drop components under ~0.05% of total face count.
2. Simplify via `open3d.geometry.TriangleMesh.simplify_vertex_clustering(voxel_size=...,
   contraction=SimplificationContraction.Quadric)` — voxel-based, topology-independent,
   so it isn't blocked by non-manifold edges.
3. Binary-search `voxel_size` (bounded by the mesh's bounding-box diagonal) to hit the
   target face count reliably, since there's no direct "target face count" parameter for
   vertex clustering.
4. Clean up with `remove_degenerate_triangles`, `remove_duplicated_triangles`,
   `remove_duplicated_vertices`, `remove_unreferenced_vertices`, then export `.obj` via trimesh.

A working reference implementation lives at `~/gaussgym/decimate_mesh.py` (generalize the
`SRC`/`FULL_OUT`/`COLLIDER_OUT` paths per scan rather than hardcoding).

If the collider still isn't watertight after this (common for NKSR output — attempted
fixes like `trimesh.repair.fill_holes()` may not close it), report this honestly rather
than claiming success; it's usable as a Unity non-convex MeshCollider but flag it for the
user as a known limitation, with voxel remeshing as a possible follow-up if strict
watertightness is required.

## Step 7 — Report

Write a Chinese `REPORT.md` into `<project>/output/<scan_name>/` covering: unzip
structure, COLMAP registration stats (and pause/relocation verification if relevant),
Brush training stats + acceptance verdict, NKSR mesh stats, decimation process, final
output file table, and a numbered "坑与解法" (pitfalls & fixes) section — be specific
about what actually failed and how it was actually fixed, not a generic list.

## Step 8 — Preview before deciding where it goes

If the user wants to sanity-check the splat before deciding what to do with it, the
fastest path (given a real X session per Step 2) is Brush's own built-in viewer:
`brush_app <ply_or_colmap_dir> --with-viewer`, which pops a native window showing the
trained splat directly on the local machine — no export/import round-trip needed.

## Step 9 — Deliver per the user's instruction

Don't assume a fixed destination (e.g. a specific VRChat asset folder) — ask, or use
whatever destination the user gives for this particular scan. Common ask: copy the
outputs to a Windows partition (dual-boot machine). If so:

- **Mounting the NTFS partition read-write from Linux has a subtle gotcha** —
  `mount -o remount,rw <mountpoint>` on an ntfs-3g/fuseblk mount can report `rw`
  successfully in `mount` output while writes still silently fail ("No such file or
  directory"/EIO on mkdir). The fix is to fully `umount` and do a fresh mount:
  `sudo mount -t ntfs-3g -o rw,uid=1000,gid=1000 /dev/sdXN /mnt/point`. Verify the volume
  is clean first with `sudo ntfsfix -n /dev/sdXN` (dry run) before enabling rw.
- After copying deliverables over, remount back to `ro` to restore the original state
  unless the user asks to leave it writable.
- If the target is a VRChat/Unity project specifically and Unity/VRChat SDK3 upload is
  being attempted from this machine: it's **not available on Ubuntu** in any practical
  form. Check `efibootmgr` for a `Windows Boot Manager` entry and whether GRUB's timeout
  is hidden (`GRUB_TIMEOUT_STYLE=hidden` in `/etc/default/grub`) — if so, tell the user to
  hold Shift or mash Esc/F12 during boot to reach the GRUB menu and select Windows. Check
  for an existing Unity install matching VRChat SDK3's recommended version before
  assuming a fresh install is needed.
