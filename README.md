# Seedbox data fetcher & extractor

Dockerised service periodically pulling data from a remote seedbox & extracting
archived files.

Note data is synced unidirectionally, but if already downloaded & processed
asset gets deleted on the remote, then it's also nuked locally. This is generally
the preferred method, as \*arr service should be responsible for torrent removal
upon successful import anyways.

## Rationale

This service aims to solve a common issue with the servarr projects around data import
(+ also provides extraction) described [here](https://forums.sonarr.tv/t/slow-transfer-from-remote-machine-fails-import/29013).
tl;dr of it is if \*arr is monitoring a directory and expecting say full season worth
of files, but by the time it goes to check/import only half of episodes have been
downloaded from your remote seedbox, then only those episodes present would be imported.

We solve this by using rclone to first download assets into an intermediary
directory not monitored by \*arr services, optionally process them (eg extract
archives), and then move them atomically to a destination directory that \*arr is
monitoring.

## Configuration

### Required environment variables

- `REMOTE`: your configured rclone remote;
- `SRC_DIR`: path to the source directory on your remote to pull data from;
- `DEST_FINAL`: path to the mounted directory in container to finally move pulled
   data to; note this would be the directory monitored by your \*arr services et al;

### Optional environment variables

- `DEST_INITIAL`: path to the mounted dir in container where rclone initially downloads
   data to; if not defined, then a directory is created inside `$DEST_FINAL`; it's 
   highly recommended you define this. Also make sure it lies on the same filesystem
   as `DEST_FINAL`, so `mv` command is atomic;
- `CRON_PATTERN`: cron pattern to be used to execute the syncing script;
   eg `*/10 * * * *` to execute every 10 minutes; defaults to every 5 min;
- `SKIP_EXTRACT`: set this to any non-empty value to skip archived file extraction;
- `SKIP_ARCHIVE_RM`: set this to any non-empty value to skip removal of archives 
   that were successfully extracted;
- `SKIP_LOCAL_RM`: set this to any non-empty value to skip removing assets in 
  `$DEST_FINAL` whose counterpart has been removed on the remote;
- `RCLONE_OPTS`: space-separated additional options to be passed to all `rclone` commands;
  useful eg if you want to override the `--bwlimit` option (which defaults to 15M);
- `PGID`: user id;
- `PUID`: group id;

### Required mountpoints & files

- you need to provide valid mountpoint to your defined `DEST_FINAL` (& `DEST_INITIAL`
  if env var is defined);
- mount point to configuration root dir at `/config` also needs to be provided;
- valid rclone config file `rclone.conf` needs to be present in `/config` mount dir;
  this conf needs to define the remote set by `REMOTE` env var;


## Example docker command:

    docker run -d \
        --name seedbox-fetcher \
        -e REMOTE=seedbox \
        -e SRC_DIR=files/complete \
        -e DEST_INITIAL=/data/tmp \
        -e DEST_FINAL=/data/complete \
        -e UID=1003 \
        -v /data/downloads/torrent-complete:/data/complete \
        -v /data/downloads/torrent-rclone-tmp:/data/tmp \
        -v $HOME/.config/seedbox-fetcher:/config \
        layr/seedbox-rclone-fetcher-extractor

## TODO

- notification systems
- healthchecks
- confirm `extract.sh/enough_space_for_extraction()` works as intended
- do we need `--tpslimit` and/or `--checkers` option?
- confirm optimal `--transfers` opt;
