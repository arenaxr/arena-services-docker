/**
 * The fbInlineScript should be the updated set of ARENA Store 'window.FileBrowser' settings.
 * WARNING: This script may be updated by future versions of https://hub.docker.com/r/filebrowser/filebrowser
 * and will have to be edited to reflect the <script> tags content that comes from our /storemng page load.
 */
const fbInlineScript =
  `window.FileBrowser = JSON.parse('{"AuthMethod":"json","BaseURL":"/storemng","CSS":false,"DisableExternal":false,"EnableExec":true,"EnableThumbs":true,"LoginPage":true,"Name":"ARENA Store","NoAuth":false,"ReCaptcha":false,"ResizePreview":true,"Signup":false,"StaticURL":"/storemng/static","Theme":"","Version":"2.16.1"}');

    var fullStaticURL = window.location.origin + window.FileBrowser.StaticURL;
    var dynamicManifest = {
      "name": window.FileBrowser.Name || 'File Browser',
      "short_name": window.FileBrowser.Name || 'File Browser',
      "icons": [
        {
          "src": fullStaticURL + "/img/icons/android-chrome-192x192.png",
          "sizes": "192x192",
          "type": "image/png"
        },
        {
          "src": fullStaticURL + "/img/icons/android-chrome-512x512.png",
          "sizes": "512x512",
          "type": "image/png"
        }
      ],
      "start_url": window.location.origin + window.FileBrowser.BaseURL,
      "display": "standalone",
      "background_color": "#ffffff",
      "theme_color": "#455a64"
    }

    const stringManifest = JSON.stringify(dynamicManifest);
    const blob = new Blob([stringManifest], {type: 'application/json'});
    const manifestURL = URL.createObjectURL(blob);
    document.querySelector('#manifestPlaceholder').setAttribute('href', manifestURL);`

const scriptHash = require("crypto")
  .createHash("sha256")
  .update(fbInlineScript)
  .digest("base64");
console.log(scriptHash);
