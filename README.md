# biggity
Cross-platform backup script

Biggity is intended for performing backups of folders or systems. If the selected source folder is a MacOS or Windows main partition, Biggity will separate the user and system files in order to be more accessbile to non-technical users.


## Windows Instructions

1. Plug in the drive (data, then power).

2. Launch Biggity. There is no need to use the Linux wrapper.

3. Open File Explorer and locate the volume of the partition you want to back up. Drag the volume onto the Biggity window when prompted for a source. Follow the rest of the prompts.

4. When the backup completes, Biggity will automatically apply proper file attributes, but it CANNOT force a sync of unwritten data on Windows. To be safe, make sure to eject the volume and verify the backup size. Note that the size on the RAID is smaller than the real size, as the filesystem is compressed.

5. Unplug the drive (power, then data).


## Linux Instructions (Xubuntu)

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

