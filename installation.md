# SteamOS installation

Instructions for setting up a SteamOS machine the way I like it, plus the
resources I used.

## OS installation

Follow Valve's official guide: [Installing SteamOS][steamos-install].

The one deviation: write the recovery image to the USB drive with `cat` from a
Linux box. The SteamOS image behaves poorly with tools like Ventoy, and a plain
byte-for-byte copy avoids the problem.

1. Download the SteamOS recovery image from the page above and decompress it
   if it is a `.bz2`:

   ```sh
   bunzip2 steamos-recovery.img.bz2
   ```

2. Plug in the USB drive and find its device name. Check carefully, because
   the next step overwrites the whole device:

   ```sh
   lsblk
   ```

3. Write the image to the drive (replace `/dev/sdX` with the **whole device**,
   not a partition like `/dev/sdX1`):

   ```sh
   sudo sh -c 'cat steamos-recovery.img > /dev/sdX'
   sync
   ```

   The `sh -c` wrapper makes the redirect run as root. A plain
   `sudo cat ... > /dev/sdX` would not, because the shell opens the file
   before `sudo` runs.

4. Boot the target machine from the USB drive and follow the installer.

## Disk encryption

SteamOS does not support full disk encryption, so don't treat the machine as
safe for sensitive information, even with the steps below. Encryption here
only protects a user's home directory, and the rest of the system stays
unencrypted.

The approach:

- Don't keep sensitive data on the machine. Use an alternate account for
  Steam and gaming rather than your main one.
- Enable home directory encryption with dirlock. Follow
  [Enabling disk encryption on the Steam Deck][dirlock].

## Windows apps

[GNOME Boxes][gnome-boxes] works well enough for running Windows apps in a VM.
Windows 11 needs some registry tinkering during setup to skip the TPM and
Secure Boot requirements. The video [Installing Windows 11 via Gnome
Boxes][boxes-video] walks through the whole process.

### Bypassing the TPM and Secure Boot checks

> These are the commonly documented steps for the Windows 11 installer. I
> haven't checked them against the video above, so adjust them to match it if
> they differ.

If the installer stops with "This PC can't run Windows 11":

1. Press `Shift+F10` to open a command prompt, then run `regedit`.
2. Go to `HKEY_LOCAL_MACHINE\SYSTEM\Setup`.
3. Right-click `Setup`, choose **New → Key**, and name it `LabConfig`.
4. Inside `LabConfig`, create two **DWORD (32-bit)** values and set each to `1`:
   - `BypassTPMCheck`
   - `BypassSecureBootCheck`
5. Close regedit and the command prompt, go back one step in the installer,
   and continue.

## Resources

- [Installing SteamOS][steamos-install]
- [Enabling home directory encryption (dirlock)][dirlock]
- [Installing Windows 11 via Gnome Boxes (video)][boxes-video]

[steamos-install]: https://help.steampowered.com/en/faqs/view/65B4-2AA3-5F37-4227
[dirlock]: https://gitlab.steamos.cloud/holo/dirlock/-/wikis/Enabling-disk-encryption-on-the-Steam-Deck
[boxes-video]: https://www.youtube.com/watch?v=7yFaVNE-0SY
[gnome-boxes]: https://wiki.gnome.org/Apps/Boxes
