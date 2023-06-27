# biggity
Cross-platform backup script

## Linux Instructions

1. Plug in the drive (data, then power).

2. Open File Manager and locate the mountpoint of the main
   partition you want to back up. It's usually called OS.
   Right click the partition and click copy.

3. Open the BIGGITY icon on the desktop. Right click in the
   window and paste (CTRL-V won't work). Follow the rest of
   the prompts.

4. When the backup completes, BIGGITY will automatically
   sync any unwritten data and apply proper file attributes
   (if applicable). Make sure to verify the backup size.
   Note that the size on the RAID is smaller than the real
   size, as the filesystem is compressed.

5. Unplug the drive (power, then data).

In case the backup fails, you can check the log in the
backup destination directory.

