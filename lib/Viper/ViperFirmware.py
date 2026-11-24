import base64
import os
import urllib.request

from robot.api import logger


class ViperFirmware(object):
    """ViperFirmware is a Robot Framework library for the firmware of a campaign.

    The DUT upgrades itself: the AMP builds the URL ``http://<server>/<image>``
    and pulls the image from there. The port of that URL is 80, the server
    address has to be a bare IP, and the image has to sit in the document
    root of that server. See images/README.md.

    So the campaign has two halves:

    - the images sit in the local directory ``images/`` and are named the way
      the build named them
    - the images are put on the firmware server before the first upgrade item
      runs, so that the DUT finds them

    | Control PC (Robot) | --HTTP PUT--> | firmware server | --HTTP--> | DUT |

    The upload is a PUT to the very URL the DUT asks for, so the file lands
    where the DUT looks for it. The server of this bench takes an anonymous
    upload; the credentials are only sent when they are filled in.
    """

    def local_images(self, image_dir, names):
        """Check the images of the campaign in the local directory.

        Returns the list of the files that are there, with their size. A file
        that is missing is reported, not raised: the caller decides whether a
        missing image is an error.

        ``image_dir:``  the local directory, e.g. ``images``
        ``names:``      the names of the images, e.g. a list of file names
        """
        found = []
        for name in names:
            path = os.path.join(image_dir, name)
            if not os.path.isfile(path):
                logger.write(f"the firmware image is not in {image_dir}: {name}", 'WARN')
                continue
            size = os.path.getsize(path)
            logger.write(f"the firmware image is there: {path} ({size} bytes)", 'INFO')
            found.append({'name': name, 'path': path, 'size': size})
        return found

    def upload(self, server, files, user='', password='', timeout=1800):
        """Put the images on the firmware server.

        ``server:``    the address of the firmware server, e.g. 172.21.48.86
        ``files:``     the list of the local files, as returned by
                       ``local_images``
        ``user:``      the user of the server, empty for an anonymous upload
        ``password:``  the password of that user
        ``timeout:``   the timeout of the request in seconds. An image is
                       about 288 MB, so it needs a generous one.
        """
        for entry in files:
            url = f"http://{server}/{entry['name']}"
            logger.write(f"uploading {entry['path']} to {url}", 'INFO')
            with open(entry['path'], 'rb') as image:
                request = urllib.request.Request(url, data=image, method='PUT')
                request.add_header('Content-Length', str(entry['size']))
                if user:
                    token = base64.b64encode(
                        f"{user}:{password}".encode()).decode()
                    request.add_header('Authorization', f'Basic {token}')
                with urllib.request.urlopen(request, timeout=timeout) as answer:
                    logger.write(
                        f"uploaded {url} ({answer.status})", 'INFO')
        return True
