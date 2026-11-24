*** Variables ***
# Template. Copy this file to variables/ and fill in your own testbed values.

# === The firmware of the campaign ===
# The DUT upgrades itself: the AMP builds the URL http://<server>/<image> and
# pulls the image from there. The port of that URL is 80, the server address
# has to be a bare IP, and the image has to sit in the document root of that
# server. See images/README.md.

# The local directory that holds the images of the campaign.
${FW_IMAGE_DIR}    images

# The HTTP server the DUT downloads the image from, and the campaign uploads
# it to. The upload is a PUT to http://<server>/<image name>.
${FW_SERVER}    <firmware_server_ip>

# The credentials of the server. Leave them empty when the server takes an
# anonymous upload.
${FW_UPLOAD_USER}    ${EMPTY}
${FW_UPLOAD_PASSWORD}    ${EMPTY}

# The image of the release that is under test. This is the line that a
# release changes.
${FW_IMAGE_NEW}    <new_release_image_name>

# The image of the release before it.
${FW_IMAGE_OLD}    <previous_release_image_name>
