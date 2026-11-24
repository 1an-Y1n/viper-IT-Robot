# The firmware of the campaign

A campaign runs against two firmware images:

| Image | What it is | Where it is declared |
|------|------------|---------------------|
| the new release | the image that is under test | `${FW_IMAGE_NEW}` in `variables/fw_variables.robot` |
| the previous release | the image the new one is compared with (CF-024, CF-025) | `${FW_IMAGE_OLD}` in the same file |

## The images are not in this repository

Every image is about **288 MB**, and the firmware server already carries every
released one:

```
http://172.21.48.28/            <- Microsoft IIS, the older set
  Viper_LE-CAMP-00.04.001-20260422073621-PROD.img
  Viper_LE-CAMP-00.04.002-20260519075519-PROD.img
  Viper_LE-CAMP-00.04.004-20260701160909-PROD.img
  Viper_LE-CAMP-00.04.005-20260929091756-PROD.img
  ...
  img_info.md                   <- the image name and its md5

http://172.21.48.86/            <- the newer set
  Viper_LE-CAMP-00.04.004MR2-20260821100009-PROD.img
  Viper_LE-CAMP-00.04.005-20261013014850-PROD.img
  Viper_LE-CAMP-00.04.005RC2-20261016074741-PROD.img
  Viper_LE-CAMP-00.04.006ER2-20261110101100-PROD.img
  ...
```

**The two servers do not carry the same images.** The reference logs of the
test template used both of them, plus two more addresses that are not
reachable from the test machine (`192.168.2.2` and `192.168.2.37`). Which
server holds the image of the release under test is therefore a value to
confirm with the release, not a constant of the project.

The DUT downloads the image itself, so nothing has to be copied into the
project:

```
FDX-AMP>$ upgradefw 172.21.48.28 Viper_LE-CAMP-00.04.006-20261112074613-PROD.img
```

The name of the file is the only thing the project has to know. `variables/
fw_variables.robot` holds it, and it is the only file a release changes.

## This directory

It holds the **local copy** of the two images of the campaign. The campaign
puts them on the firmware server itself, before the first upgrade item runs:

```
IT_ENV/IT-ENV-001           the environment check
  -> IT ENV - The Firmware Images Are In The Local Directory
  -> IT ENV - The Firmware Images Are Uploaded To The Server   (HTTP PUT)
  -> IT ENV - The Firmware Images Are On The Server             (HEAD from the DUT)
```

The upload is a **PUT to the very URL the DUT asks for**
(`http://<server>/<image name>`), so the image lands where the DUT looks for
it. The server of this bench takes an anonymous upload; the credentials in
`variables/fw_variables.robot` are only sent when they are filled in.

The `.img` files in this directory are ignored by git, so a local copy never
ends up in a commit.

## Before a campaign

The image of the release has to be on the server before the first upgrade
item runs. The check is one request from the DUT:

```bash
FDX-AMP>$ debug shell
bash-3.2# curl -sI --max-time 25 http://172.21.48.28/<image name> | head -n 2
HTTP/1.1 200 OK
Content-Length: 288534359
```

A missing image answers `404 Not Found`. The suite does the same check
before it starts an upgrade, see `IT COMMON - Firmware Image Should Be On
Server` in `resource/Common/IT_Common.resource`.

## The naming

The name comes from the build, it is not something the test invents:

```
Viper_LE-CAMP-<version>-<build timestamp>-<PROD|DEV>.img
```

`PROD` is the signed image, `DEV` the development one. The firmware server
keeps the md5 of the images next to them in `img_info.md`.
