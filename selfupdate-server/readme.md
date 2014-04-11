# finkinfo mirrors

## Description

These scripts are for setting up finkinfo mirrors.

These are the mirrors that hold the fink .info and .patch files retrieved by fink when doing a 'fink selfupdate'.

## Sample rsync setup

This needs to be retrieved via anonymous rsync. These files can be placed anywhere, but make sure your rsync site has the tag `finkinfo` available, and pointing to the directory containing these files.

```ini
[finkinfo]
	path = /Path/src/fink/finkinfo
	comment = Fink .info files
```

## Mirroring Method

There are scripts for updating a mirror directly from `cvs` (and eventually `git`) or via `rsync`.

Mirrors must update at an interval between 15 to 90 minutes.
30 minutes is recommended for mirrors updating via `rsync`.
Mirrors updating directly from the repository should update as often as they have the resources to do so within the acceptable interval.

The official scripts will timeout on network operations after 10 minutes.

### `finkcvsup`
Requires coreutils to be installed to provide `timeout`.

#### Command Line Options
**`-l`:** Sets the lockfile; `/var/run/finkrsyncup.lock` by default.

**`-o`:** Sets the output directory; `/Volumes/src2/fink/selfupdate` by default.

**`-u`:** Sets the ssh user; `finkcvs` by default.

**`-q`:** Makes cvs quiet.

#### Environment Variables
**`TIMEOUT`:** Sets the name of the `timeout` command; `timeout` by default.

### `finkrsyncup`

#### Command Line Options
**`-l`:** Sets the lockfile; `/var/run/finkrsyncup.lock` by default.

**`-o`:** Sets the output directory; `/Volumes/src2/fink/selfupdate` by default.

#### Environment Variables
**`RSYNCPTH`:** Sets the uri to sync from; `rsync://distfiles.master.finkmirrors.net/finkinfo/` by default.

### `finkgitup`

#### Command Line Options
**`-l`:** Sets the lockfile; `/var/run/finkrsyncup.lock` by default.

**`-o`:** Sets the output directory; `/Volumes/src2/fink/selfupdate` by default.

#### Environment Variables
**`REPOPTH`:** Sets the uri to sync from; `https://github.com/danielj7/fink-dists.git` by default.

## Timestamps

The mirroring network uses three timestamp files to track mirror health.

### `TIMESTAMP`
Updated when data is successfully refreshed form the repository.
Must always be fetched separately and after the successful retrieval of all other data by rsync driven mirrors.

### `LOCAL`
Must be set by every mirror after a successful update cycle even if no data has actually been changed.

### `UPDATE`
Must be set and publicly available by every mirror at the start of each update cycle.

## DNS Structure

Generally speaking the Fink mirror structure is as follows and please keep in mind these dns entries aren't typically for human use. `[yourairporttag].[state].[continent].finkmirrors.net` and `[yourairporttag].finkmirrors.net` as a shortcut will be used for rsync mirrors of the Fink info files.

## Mailing List

If you run (or want to run) a mirror you should subscribe to fink-mirrors-request@lists.sourceforge.net.

It is important that the person monitoring the list on behalf of a mirror can administrate the mirror should any issues arise.
