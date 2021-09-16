/**
 * Get filebrowser index.html and gets the inline script hash
 * WARNING: This script may need to be updated by future versions of https://hub.docker.com/r/filebrowser/filebrowser
 */
const http = require('http');

http.get(process.argv[2], (res) => {
    const data = [];
    res.on('data', (chunk) => {
        data.push(chunk);
    });

    res.on('end', () => {
        const html = Buffer.concat(data).toString();

        const fbInlineScript = html.match(/<script>([\S\s]*?)<\/script>/gm)[0].replace(/<.?script>/gm, '');
        const scriptHash = require('crypto')
            .createHash('sha256')
            .update(fbInlineScript)
            .digest('base64');
        console.log(scriptHash);
    });
}).on('error', (err) => {
    console.log('Error: ', err.message);
});
